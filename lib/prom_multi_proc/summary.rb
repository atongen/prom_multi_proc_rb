# frozen_string_literal: true

module PromMultiProc
  class Summary < Collector
    def observe(value, labels = {})
      write("observe", value, labels)
    end
  end
end
