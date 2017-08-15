module PromMultiProc
  class Collector
    attr_reader :name, :metric_methods

    def initialize(name, label_keys, writer)
      @name = name
      @label_keys = label_keys
      @writer = writer
      @metric_methods = (public_methods(false) - %i(
        validate!
        valid_method? valid_label_keys? valid_label_values? valid_value?
        to_msg
      )).map(&:to_s)
    end

    def validate!(method, value, labels)
      unless valid_method?(method)
        raise PromMultiProcError.new("Invalid metric method (#{method}): try: #{metric_methods.inspect}")
      end
      unless valid_label_keys?(labels)
        raise PromMultiProcError.new("Invalid label cardinality (#{name}): #{labels.keys.inspect}, need keys: #{@label_keys.inspect}")
      end
      unless valid_label_values?(labels)
        raise PromMultiProcError.new("Invalid label values (#{name}): #{labels.values.inspect}")
      end
      unless valid_value?(value)
        raise PromMultiProcError.new("Invalid value (#{name}): #{value.inspect} (must be numeric)")
      end
    end

    def valid_method?(method)
      metric_methods.include?(method)
    end

    def valid_label_keys?(labels)
      labels.keys == @label_keys
    end

    def valid_label_values?(labels)
      labels.values.all? { |v| v.is_a?(String) || v.is_a?(Symbol) }
    end

    def valid_value?(value)
      value.is_a?(Numeric)
    end

    def to_msg(method, value, labels)
      { "name" => name,
        "method" => method,
        "value" => value.to_f,
        "label_values" => labels.values }
    end

  private

    def write(method, value, labels)
      @writer.write(self, method, value, labels)
    end
  end
end
