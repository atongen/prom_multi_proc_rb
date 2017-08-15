module PromMultiProc
  class Gauge < Collector
    def set(value, labels = {})
      write("set".freeze, value, labels)
    end

    def inc(labels = {})
      write("inc".freeze, 1, labels)
    end

    def dec(labels = {})
      write("dec".freeze, 1, labels)
    end

    def add(value, labels = {})
      write("add".freeze, value, labels)
    end

    def sub(value, labels = {})
      write("sub".freeze, value, labels)
    end

    def set_to_current_time(labels = {})
      write("set_to_current_time".freeze, 1, labels)
    end
  end
end
