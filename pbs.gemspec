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
  spec.summary       = %q{Ruby gem that uses FFI to interface with Adaptive Computing's resource manager Torque}
  spec.description   = %q{Ruby wrapper for the Torque C library utilizing Ruby-FFI. This has been successfully tested with Torque 4.2.10 and greater. Your mileage may vary.}
  spec.homepage      = "https://github.com/OSC/pbs-ruby"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]
  spec.required_ruby_version = '~> 2.2'

  spec.add_runtime_dependency "ffi", "~> 1.9", ">= 1.9.6"
  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
end
