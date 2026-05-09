# frozen_string_literal: true

module PromMultiProc
  class Gauge < Collector
    def set(value, labels = {})
      write("set", value, labels)
    end

    def inc(labels = {})
      write("inc", 1, labels)
    end

    def dec(labels = {})
      write("dec", 1, labels)
    end

    def add(value, labels = {})
      write("add", value, labels)
    end

    def sub(value, labels = {})
      write("sub", value, labels)
    end

    def set_to_current_time(labels = {})
      write("set_to_current_time", 1, labels)
    end
  end
end
