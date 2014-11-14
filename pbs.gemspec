require File.expand_path("../lib/#{File.basename(__FILE__, '.gemspec')}/version", __FILE__)

Gem::Specification.new do |s|
  s.name = 'pbs'
  s.version = PBS::VERSION
  s.author = 'Jeremy Nicklas'
  s.email = 'jnicklas@osc.edu'
  s.homepage = 'http://www.osc.edu'
  s.summary = 'PBS Ruby'
  s.description = 'Ruby Torque (PBS) Library'

  s.files = `git ls-files`.split($/)
  s.license = 'BSD'

  s.add_runtime_dependency 'ffi', '~> 1.9.6'
end
