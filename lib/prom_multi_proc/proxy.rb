module PromMultiProc
  class Proxy
    attr_reader :multis

    def initialize(base)
      @base = base
      @proxies = {}
      @multis = []

      add_proxy_methods
    end

    def add_multi(collector, method, value, labels)
      @multis << [collector, method, value, labels]
    end

  private

    def add_proxy_methods
      @base.metrics.each do |name|
        @proxies[name] = ProxyCollector.new(self, @base.metric(name))
        define_singleton_method(name) do
          @proxies[name]
        end
      end
    end
  end

  class ProxyCollector
    def initialize(proxy, collector)
      @proxy = proxy
      @collector = collector

      add_proxy_methods
    end

  private

    def add_proxy_methods
      @collector.metric_methods.each do |meth|
        define_singleton_method(meth) do |*args|
          case args.length
          when 0
            value = 1.0
            labels = {}
          when 1
            if args[0].is_a?(Hash)
              value = 1.0
              labels = args[0]
            else
              value = args[0]
              labels = {}
            end
          when 2
            value = args[0]
            labels = args[1]
          else
            raise PromMultiProcError.new("Invalid number of arguments")
          end

          @proxy.add_multi(@collector, meth, value, labels)
        end
      end
    end
  end
end
