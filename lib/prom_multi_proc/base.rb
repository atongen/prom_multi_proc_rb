require "logger"
require "concurrent"

module PromMultiProc
  class Base
    attr_reader :logger, :prefix, :writer

    def initialize(socket:, metrics:, batch_size: 1, batch_timeout: 3, logger: nil, validate: false, prefix: "")
      @prefix = prefix
      @logger = logger || ::Logger.new(STDOUT)

      unless File.socket?(socket)
        @logger.warn("Socket does not exist: #{socket}")
      end

      @metric_objects = Concurrent::Map.new
      @writer = Writer.new(socket: socket, batch_size: batch_size, batch_timeout: batch_timeout, validate: validate)
      @multi_lock = Mutex.new

      specs = get_specs(metrics)
      process_specs!(specs)
    end

    def metric(name)
      @metric_objects[name]
    end

    def metric?(name)
      @metric_objects.key?(name)
    end

    def metrics
      @metric_objects.keys
    end

    def multi
      return unless block_given?
      result = @multi_lock.synchronize do
        Proxy.new(self).tap do |proxy|
          yield(proxy)
        end
      end
      @writer.write_multi(result.multis)
    end

  private

    def valid_metric?(name)
      !!METRIC_RE.match(name)
    end

    def get_specs(file)
      unless File.file?(file)
        raise PromMultiProcError.new("Metric definition file not found: #{file}")
      end

      begin
        JSON.parse(File.read(file))
      rescue JSON::ParserError => e
        raise PromMultiProcError.new("Metric definition file (#{file}) is not valid json: #{e}")
      end
    end

    def process_specs!(specs)
      specs.each { |spec| process_spec!(spec) }
    end

    def process_spec!(spec)
      klazz = TYPES[spec["type"].to_sym]
      unless klazz
        raise PromMultiProcError.new("Unkown type: #{spec.inspect}")
      end

      unless valid_metric?(spec["name"])
        raise PromMultiProcError.new("Invalid name: #{spec.inspect}")
      end

      unless spec["name"].start_with?(prefix)
        raise PromMultiProcError.new("Metric '#{spec['name']}' must start with prefix '#{prefix}'")
      end
      name = spec["name"].sub(/\A#{prefix}/, "").to_sym

      labels = (spec["labels"] || []).map(&:to_sym)
      unless labels.all? { |l| valid_metric?(l)  }
        raise PromMultiProcError.new("Invalid label: #{spec.inspect}")
      end

      if self.class.instance_methods(false).include?(name) || methods(false).include?(name)
        raise PromMultiProcError.new("Metric method exists: #{name}")
      end

      if @metric_objects.key?(name)
        raise PromMultiProcError.new("Metric already exists: #{name}")
      end

      @metric_objects[name] = klazz.new(spec["name"], labels, @writer)

      define_singleton_method(name) do
        @metric_objects[name]
      end
    end
  end
end
