# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ood_core/version'

Gem::Specification.new do |spec|
  spec.name          = "ood_core"
  spec.version       = OodCore::VERSION
  spec.authors       = ["Jeremy Nicklas"]
  spec.email         = ["jnicklas@osc.edu"]

  spec.summary       = %q{Open OnDemand core library}
  spec.description   = %q{Open OnDemand core library that provides support for an HPC Center to globally define HPC services that web applications can then take advantage of.}
  spec.homepage      = "https://github.com/OSC/ood_core"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.required_ruby_version = ">= 2.2.0"

  spec.add_runtime_dependency "ood_support", "~> 0.0.2"
  spec.add_development_dependency "pbs", "~> 2.1", ">= 2.2.0"
  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "pry", "~> 0.10"
  spec.add_development_dependency "timecop", "~> 0.8"
  spec.add_development_dependency "minitest"
end
