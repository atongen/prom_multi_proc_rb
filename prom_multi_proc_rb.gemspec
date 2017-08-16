# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "prom_multi_proc/version"

Gem::Specification.new do |spec|
  spec.name          = "prom_multi_proc_rb"
  spec.version       = PromMultiProc::VERSION
  spec.authors       = ["Andrew Tongen"]
  spec.email         = ["atongen@gmail.com"]

  spec.summary       = %q{A ruby library for collecting prometheus metrics within forking servers}
  spec.description   = %q{A ruby library for collecting prometheus metrics within forking servers}
  spec.homepage      = "https://github.com/atongen/prom_multi_proc_rb"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "https://rubygems.org"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "bin"
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.15"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rspec-collection_matchers", "~> 1.0"

  spec.add_dependency "concurrent-ruby", "~> 1.0", ">= 1.0.2"
end
