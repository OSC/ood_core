require 'test_helper'
require 'ood_core/job/adapter.rb'

ADAPTER_FILES = Dir[File.join('ood_core', 'job', 'adapters', '*.rb')]
ADAPTER_FILES.each { |file| require file }

class AdapterTest < Minitest::Test
  BASE = OodCore::Job::Adapter

  # Every concrete class descending from the base adapter 
  def adapters
    ObjectSpace.each_object(Class).select { |klass| klass < BASE }
  end

  # Public methods defined by the base class itself (not inherited from Object)
  def base_methods
    BASE.public_instance_methods(false)
  end

  def test_adapters_were_found
    refute_empty adapters, 'No subclasses of OodCore::Job::Adapter were found'
  end

  def test_adapter_interfaces_match_base_class
    adapters.each do |adapter|
      base_methods.each do |name|
        impl = adapter.instance_method(name)

        # Case 2: not overridden, so the base class method runs
        next if impl.owner == BASE

        # Case 1: overridden, so the signature must match the base exactly
        expected = BASE.instance_method(name).parameters
        actual   = impl.parameters

        assert_equal expected, actual,
          "#{adapter}##{name} (defined in #{impl.owner}) has parameters " \
          "#{actual.inspect}, but #{BASE}##{name} defines #{expected.inspect}"
      end
    end
  end
end