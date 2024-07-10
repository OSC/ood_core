require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "minitest/test_task"

RSpec::Core::RakeTask.new(:spec)


Minitest::TestTask.create(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.warning = false
  t.test_globs = ["test/**/*_test.rb"]
end

task :default => :spec
