# frozen_string_literal: true

require "logger"
require "concurrent"

module PromMultiProc
  class Base
    attr_reader :logger, :prefix, :writer

    def initialize(socket:, metrics:, batch_size: nil, batch_timeout: nil, logger: nil, validate: false, prefix: "")
      @prefix = if prefix.empty? || prefix.end_with?("_")
        prefix
      else
        "#{prefix}_"
      end
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
        proxy = Proxy.new(self)
        yield(proxy)
        proxy
      end
      @writer.write_multi(result.multis)
    end

  private

    def valid_metric?(name)
      METRIC_RE.match?(name)
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
        raise PromMultiProcError.new("Unknown type: #{spec.inspect}")
      end

      unless valid_metric?(spec["name"])
        raise PromMultiProcError.new("Invalid name: #{spec.inspect}")
      end

      full_name = if prefix.empty? || spec["name"].start_with?(prefix)
        spec["name"]
      else
        "#{prefix}#{spec["name"]}"
      end
      name = full_name.sub(/\A#{Regexp.escape(prefix)}/, "").to_sym

      unless spec["help"] && !spec["help"].strip.empty?
        raise PromMultiProcError.new("Metric '#{spec['name']}' is missing help")
      end

      labels = (spec["labels"] || []).map(&:to_sym)
      unless labels.all? { |l| valid_metric?(l) }
        raise PromMultiProcError.new("Invalid label: #{spec.inspect}")
      end

      if @metric_objects.key?(name)
        raise PromMultiProcError.new("Metric already exists: #{name}")
      end

      if respond_to?(name)
        raise PromMultiProcError.new("Metric method conflicts with existing method: #{name}")
      end

      @metric_objects[name] = klazz.new(full_name, labels, @writer)

      define_singleton_method(name) do
        @metric_objects[name]
      end
    end
  end
end
