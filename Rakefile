require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "minitest/test_task"

require_relative 'lib/tasks/slurm'

RSpec::Core::RakeTask.new(:spec)


Minitest::TestTask.create(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.warning = false
  # Minitest::TestTask doesn't read TEST on its own, so without this
  # `rake test TEST=test/some_test.rb` runs every test file.
  t.test_globs = [ENV["TEST"] || "test/**/*_test.rb"]

  if ENV["TEST"] && Dir[ENV["TEST"]].empty?
    abort("TEST=#{ENV["TEST"]} doesn't match any test files")
  end
end

task :default => :spec
