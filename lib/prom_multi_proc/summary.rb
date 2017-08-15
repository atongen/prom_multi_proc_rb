module PromMultiProc
  class Summary < Collector
    def observe(value, labels = {})
      write("observe".freeze, value, labels)
    end
  end
end
