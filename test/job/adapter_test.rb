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

        # If the method is not overridden, the base class method runs
        next if impl.owner == BASE

        # If it is overridden, the signature must match the base exactly
        expected = BASE.instance_method(name).parameters
        actual   = impl.parameters
        msg = "was not found or is incompatible in the method signature of #{adapter}##{name}, but #{BASE}##{name} defines #{expected.inspect}"
        hasrest = actual.any? { |arg| arg[0] == :rest }
        haskwrest = actual.any? { |arg| arg[0] == :keyrest }

        # Extract sub-arrays to safely look up actual arguments without index mixing
        actual_positionals = actual.select { |t, _| [:req, :opt].include?(t) }
        actual_keywords    = actual.select { |t, _| [:keyreq, :key].include?(t) }.to_h { |t, n| [n, t] }

        positional_index = 0

        expected.each do |type, argname|
          case type
          when :req
            # required args can become optional, or be included in a rest param
            unless hasrest
              actual_param = actual_positionals[positional_index]
              assert actual_param && [:req, :opt].include?(actual_param[0]), "required positional arg :#{argname} #{msg}"
            end
            positional_index += 1

          when :opt
            # optional args must stay optional or be included in a rest param
            unless hasrest
              actual_param = actual_positionals[positional_index]
              assert actual_param && actual_param[0] == :opt, "optional positional arg :#{argname} #{msg}"
            end
            positional_index += 1

          when :rest
            assert hasrest, "rest param :#{argname} #{msg}"

          when :keyreq
            unless haskwrest
              actual_type = actual_keywords[argname]
              assert [:keyreq, :key].include?(actual_type), "required keyword arg :#{argname} #{msg}"
            end

          when :key
            unless haskwrest
              actual_type = actual_keywords[argname]
              assert actual_type == :key, "optional keyword arg :#{argname} #{msg}"
            end

          when :keyrest
            assert haskwrest, "keyword rest param :#{argname} #{msg}"
          end
        end
      end
    end
  end
end