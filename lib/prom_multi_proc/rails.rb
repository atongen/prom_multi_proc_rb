# frozen_string_literal: true

require "logger"

module PromMultiProc
  module Rails
    def self.init(**options)
      program_name = File.basename($PROGRAM_NAME)
      app_name = ::Rails.application.class.name.underscore.split("/").first

      defaults = {
        prefix:        "#{app_name}_",
        socket:        ENV.fetch("PROM_MULTI_PROC_SOCKET", ::Rails.root.join("tmp/sockets/metrics.sock").to_s),
        metrics:       ENV.fetch("PROM_MULTI_PROC_DEFINITION_FILE", ::Rails.root.join("config/metrics.json").to_s),
        batch_size:    default_batch_size(program_name),
        batch_timeout: 3,
        validate:      ::Rails.env.development? || ::Rails.env.test?,
        logger:        ::Rails.logger || ::Logger.new(STDOUT)
      }

      config = defaults.merge(options)
      config[:logger].info("Setting up prom_multi_proc for #{app_name}-#{program_name}, batch_size: #{config[:batch_size]}, batch_timeout: #{config[:batch_timeout]}, validate: #{config[:validate]}")

      Base.new(**config)
    end

    def self.default_batch_size(program_name)
      if %w(rails rake).include?(program_name) || ::Rails.env.development? || ::Rails.env.test?
        1
      elsif ::Rails.env.production?
        100
      else
        5
      end
    end
    private_class_method :default_batch_size
  end
end
