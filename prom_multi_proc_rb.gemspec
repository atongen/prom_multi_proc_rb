# frozen_string_literal: true

lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "prom_multi_proc/version"

Gem::Specification.new do |spec|
  spec.name          = "prom_multi_proc_rb"
  spec.version       = PromMultiProc::VERSION
  spec.authors       = ["Andrew Tongen"]
  spec.email         = ["atongen@gmail.com"]

  spec.summary       = "A ruby library for collecting prometheus metrics within forking servers"
  spec.description   = "A ruby library for collecting prometheus metrics within forking servers"
  spec.homepage      = "https://github.com/atongen/prom_multi_proc_rb"
  spec.license       = "MIT"

  spec.required_ruby_version = ">= 2.7"

  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "https://rubygems.org"
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "bin"
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", ">= 2.0"
  spec.add_development_dependency "rake", ">= 13.0"
  spec.add_development_dependency "rspec", "~> 3.13"
  spec.add_development_dependency "rspec-collection_matchers", "~> 1.2"

  spec.add_dependency "concurrent-ruby", "~> 1.1"
  spec.add_dependency "logger", ">= 1.5"
end
