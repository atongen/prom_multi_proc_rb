# frozen_string_literal: true

module PromMultiProc
  class Counter < Collector
    def inc(labels = {})
      write("inc", 1, labels)
    end

    def add(value, labels = {})
      write("add", value, labels)
    end
  end
end
