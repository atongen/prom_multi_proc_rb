module PromMultiProc
  module Rails
    def self.init(prefix = nil)
      metrics = ENV.fetch("PROM_MULTI_PROC_DEFINITION_FILE", ::Rails.root.join("config/metrics.json").to_s)
      socket = ENV.fetch("PROM_MULTI_PROC_SOCKET", ::Rails.root.join("tmp/sockets/metrics.sock").to_s)

      program_name = File.basename($PROGRAM_NAME)
      prefix ||= ::Rails.application.class.name.underscore.split("/").first + "_"

      if ENV.key?("PROM_MULTI_PROC_BATCH_SIZE")
        batch_size = ENV["PROM_MULTI_PROC_BATCH_SIZE"].to_i
      elsif %w(rails rake).include?(name) || ::Rails.env.development? || ::Rails.env.test?
        batch_size = 1
      elsif ::Rails.env.production?
        batch_size = 100
      else
        batch_size = 5
      end

      if ::Rails.env.development? || ::Rails.env.test?
        validate = true
      else
        validate = false
      end

      ::Rails.logger.error("Setting up metrics for #{program_name}, batch size: #{batch_size}, validate: #{validate}")

      Base.new(
        prefix: prefix,
        socket: socket,
        metrics: metrics,
        batch_size: batch_size,
        validate: validate,
        logger: ::Rails.logger
      )
    end
  end
end
