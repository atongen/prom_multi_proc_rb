module PromMultiProc
  class Writer
    attr_reader :socket, :batch_size, :batch_timeout

    def initialize(socket:, batch_size: 1, batch_timeout: 3, validate: false)
      if !batch_size.is_a?(Integer) || batch_size <= 0
        raise PromMultiProcError.new("Invalid batch size: #{batch_size}")
      end
      if !batch_timeout.is_a?(Integer) || batch_timeout <= 0
        raise PromMultiProcError.new("Invalid batch timeout: #{batch_timeout}")
      end
      @batch_size = batch_size
      @batch_timeout = batch_timeout
      @validate = !!validate

      @lock = Mutex.new
      @thread = Thread.new {
        loop do
          sleep(batch_timeout)
          flush(force: true)
        end
      }
      @messages = []

      @socket = socket
    end

    def validate?
      @validate
    end

    def write(metric, method, value, labels)
      @lock.synchronize do
        metric.validate!(method, value, labels) if validate?
        @messages << metric.to_msg(method, value, labels)
      end

      flush
    end

    # array of arrays where inner array is length 4 matching arguments
    # for signature of #write
    def write_multi(metrics)
      @lock.synchronize do
        if validate?
          metrics.each do |m, method, value, labels|
            m.validate!(method, value, labels)
          end
        end

        metrics.each do |m, method, value, labels|
          @messages << m.to_msg(method, value, labels)
        end
      end

      flush
    end

    def flush(force: false)
      @lock.synchronize do
        if force && @messages.length > 0 || @messages.length >= batch_size
          begin
            write_socket(JSON.generate(@messages))
          ensure
            @messages.clear
          end
        else
          true
        end
      end
    end

    def socket?
      !!write_socket("\n")
    end

  private

    def write_socket(msg)
      s = UNIXSocket.new(@socket)
      s.send(msg, 0)
      s.close
      true
    rescue StandardError
      false
    end
  end
end
