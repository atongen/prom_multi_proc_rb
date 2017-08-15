module PromMultiProc
  class Railtie < Rails::Railtie
    initializer "prom_multi_proc.configure_rails_initialization" do
      $metrics = init
    end

    def self.init
      metrics = ENV.fetch("PROM_MULTI_PROC_DEFINITION_FILE", Rails.root.join("config/metrics.json").to_s)
      socket = ENV.fetch("PROM_MULTI_PROC_SOCKET", Rails.root.join("tmp/sockets/metrics.sock").to_s)

      name = File.basename($PROGRAM_NAME)

      if ENV.key?("PROM_MULTI_PROC_BATCH_SIZE")
        batch_size = ENV["PROM_MULTI_PROC_BATCH_SIZE"].to_i
      elsif %w(rails rake).include?(name) || Rails.env.development? || Rails.env.test?
        batch_size = 1
      elsif Rails.env.production?
        batch_size = 100
      else
        batch_size = 5
      end

      if Rails.env.development? || Rails.env.test?
        validate = true
      else
        validate = false
      end

      Rails.logger.error("Setting up metrics for #{name}, batch size: #{batch_size}, validate: #{validate}")

      Base.new(
        prefix: "drip_",
        socket: socket,
        metrics: metrics,
        batch_size: batch_size,
        validate: validate,
        logger: Rails.logger
      )
    end
  end
end
