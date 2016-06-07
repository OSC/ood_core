# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'pbs/version'

Gem::Specification.new do |spec|
  spec.name          = "pbs"
  spec.version       = PBS::VERSION
  spec.platform      = Gem::Platform::RUBY
  spec.authors       = ["Jeremy Nicklas"]
  spec.email         = ["jnicklas@osc.edu"]
  spec.summary       = %q{PBS FFI Ruby gem to use FFI to interface with Adaptive Computing's resource manager Torque}
  spec.description   = %q{PBS FFI Ruby gem to use FFI to interface with Adaptive Computing's resource manager Torque}
  spec.homepage      = "https://github.com/OSC/pbs-ruby"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "ffi", "~> 1.9", ">= 1.9.6"
  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
end
