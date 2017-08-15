module PromMultiProc
  class Histogram < Collector
    def observe(value, labels = {})
      write("observe".freeze, value, labels)
    end
  end
end
