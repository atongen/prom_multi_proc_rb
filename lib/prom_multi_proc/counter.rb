module PromMultiProc
  class Counter < Collector
    def inc(labels = {})
      write("inc".freeze, 1, labels)
    end

    def add(value, labels = {})
      write("add".freeze, value, labels)
    end
  end
end
