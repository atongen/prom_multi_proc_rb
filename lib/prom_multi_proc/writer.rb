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
      @shutdown = false

      start_flush_thread
    end

    def validate?
      @validate
    end

    def shutdown
      # Read @thread under the lock that start_flush_thread writes it, so a post
      # fork restart racing SIGTERM can't leave us killing a stale dead thread.
      thread = @lock.synchronize do
        @shutdown = true
        @thread
      end

      return unless thread&.alive?

      flush(force: true) # outside the lock; flush takes it
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

    # Threads do not survive fork, so in a pre-forking server (unicorn with
    # preload_app, puma cluster mode, resque...) every worker inherits a dead
    # flush thread. Notice the pid change on the first write/flush in the child
    # and start a new one there. The inherited buffer is dropped: the parent
    # still owns those messages and sends them itself.
    def ensure_flush_thread
      return if @thread_pid == Process.pid

      @lock.synchronize do
        return if @thread_pid == Process.pid # another thread won the race
        return if @shutdown

        @messages.clear
        start_flush_thread
      end
    end

    # @thread_pid is assigned before Thread.new so the new thread's first flush
    # takes the fast path above instead of spawning a second thread.
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
