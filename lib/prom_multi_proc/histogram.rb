# frozen_string_literal: true

module PromMultiProc
  class Histogram < Collector
    def observe(value, labels = {})
      write("observe", value, labels)
    end
  end
end
