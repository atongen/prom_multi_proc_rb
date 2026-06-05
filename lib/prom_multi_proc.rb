# frozen_string_literal: true

require "socket"
require "json"

require "prom_multi_proc/version"

require "prom_multi_proc/collector"
require "prom_multi_proc/counter"
require "prom_multi_proc/gauge"
require "prom_multi_proc/histogram"
require "prom_multi_proc/summary"

require "prom_multi_proc/writer"
require "prom_multi_proc/proxy"
require "prom_multi_proc/base"

module PromMultiProc
  class PromMultiProcError < StandardError; end

  TYPES = {
    counter:   Counter,
    gauge:     Gauge,
    histogram: Histogram,
    summary:   Summary
  }.freeze

  METRIC_RE = /\A[a-z]+[0-9a-z_]+\Z/.freeze
end

require "prom_multi_proc/rails" if defined?(::Rails)
