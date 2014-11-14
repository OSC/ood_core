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
end
