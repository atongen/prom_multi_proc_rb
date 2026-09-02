# frozen_string_literal: true

module PromMultiProc
  class Writer
    attr_reader :socket, :batch_size, :batch_timeout

    def initialize(socket:, batch_size: nil, batch_timeout: nil, validate: false)
      batch_size = 1 if batch_size.nil?
      batch_timeout = 3 if batch_timeout.nil?
      unless batch_size.is_a?(Integer) && batch_size > 0
        raise PromMultiProcError.new("Invalid batch size: #{batch_size}")
      end
      unless batch_timeout.is_a?(Integer) && batch_timeout > 0
        raise PromMultiProcError.new("Invalid batch timeout: #{batch_timeout}")
      end

      @batch_size = batch_size
      @batch_timeout = batch_timeout
      @validate = validate
      @socket = socket

      @messages = []
      @lock = Mutex.new
      @thread_lock = Mutex.new
      @shutdown = false

      start_flush_thread
    end

    def validate?
      @validate
    end

    def shutdown
      # Read @thread under the same lock that start_flush_thread writes it, so a
      # request thread starting a post fork flusher concurrently with SIGTERM
      # can't leave us looking at the stale, already dead thread and skipping
      # both the flush and the kill. #flush is deliberately called outside the
      # lock (see #ensure_flush_thread).
      thread = @thread_lock.synchronize do
        @shutdown = true
        @thread
      end

      return unless thread&.alive?

      flush(force: true)
      thread.kill
    end

    def write(metric, method, value, labels)
      write_multi([[metric, method, value, labels]])
    end

    # array of arrays where inner array is length 4 matching arguments
    # for signature of #write
    def write_multi(metrics)
      # Before anything is buffered, so that a post fork restart discards only
      # the messages this process inherited, never the ones it just wrote.
      ensure_flush_thread

      if validate?
        metrics.each do |m, method, value, labels|
          m.validate!(method, value, labels)
        end
      end

      @lock.synchronize do
        metrics.each do |m, method, value, labels|
          @messages << m.to_msg(method, value, labels)
        end
      end

      flush
    end

    def flush(force: false)
      ensure_flush_thread

      @lock.synchronize do
        if (force && @messages.length > 0) || (@messages.length >= batch_size)
          begin
            if socket?
              @warned_no_socket = false
              write_socket(JSON.generate(@messages))
            else
              # Normal state when the daemon isn't running (CI, dev, one-off
              # rake tasks) — warn once instead of once per batch
              unless @warned_no_socket
                warn("prom_multi_proc_rb - flush: socket #{@socket} not available, dropping metrics")
                @warned_no_socket = true
              end
              false
            end
          rescue StandardError => e
            # Never raise into host app; drop the batch
            warn("prom_multi_proc_rb - flush: Failed to write batch to socket #{e}")
            false
          ensure
            @messages.clear
          end
        else
          true
        end
      end
    end

    def socket?
      File.socket?(@socket) && File.writable?(@socket)
    rescue StandardError
      false
    end

  private

    # Threads do not survive fork: in a pre-forking server (unicorn with
    # preload_app, puma in cluster mode, resque...) the writer is built in the
    # parent, and every worker inherits it with a dead flush thread. Metrics
    # then only leave the process when a write happens to fill batch_size, and
    # whatever is buffered below that is lost when the worker is reaped.
    #
    # Rather than depend on the host app calling an after_fork hook, notice the
    # pid change on the first write/flush in the child and start a new thread
    # there. The common case is a plain integer comparison, no lock taken.
    #
    # INVARIANT: never call #flush while holding @thread_lock. #flush calls this
    # method, so a flush from inside the lock would re-enter @thread_lock on the
    # same thread and raise ThreadError: recursive locking -- and only ever in a
    # forked child, since that is the only case that gets past the pid check.
    def ensure_flush_thread
      return if @thread_pid == Process.pid

      @thread_lock.synchronize do
        # Another thread in this process may have won the race while we waited.
        return if @thread_pid == Process.pid
        return if @shutdown

        # Anything buffered at fork time was written by the parent, and in the
        # usual case (a long lived master forking workers) the parent still has
        # its own copy and its own live thread to send it, so keeping it here
        # would double count it once per worker. A parent that exits right after
        # forking loses that buffer instead, but dropping it is the safer
        # default: over reporting a metric is worse than under reporting it.
        @lock.synchronize { @messages.clear }

        start_flush_thread
      end
    end

    # Assigns @thread_pid *before* spawning. That ordering is load bearing on
    # the constructor path, which runs with no lock held: with the assignment
    # after Thread.new, the new thread's first #flush can reach
    # #ensure_flush_thread while @thread_pid is still nil, take the uncontended
    # @thread_lock, clear the buffer and spawn a second flush thread. The result
    # is a leaked thread and a spurious clear, not a deadlock -- the spawner
    # never waits on the thread it starts.
    def start_flush_thread
      @thread_pid = Process.pid
      @thread = Thread.new do
        loop do
          flush(force: true)
          sleep(@batch_timeout)
        end
      end
    end

    def write_socket(msg)
      s = UNIXSocket.new(@socket)
      s.send(msg, 0)
      true
    ensure
      s&.close
    end
  end
end
