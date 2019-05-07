# Builds a sorted array of job ids given a job array spec string
#
# Job array spec strings:
#   1         Single id
#   1-10      Range
#   1-10:2    Range with step
#   1-10,13   Compound (range with single id)
#
# Note that Ranges are expected to be inclusive
module OodCore
  module Job
    class ArrayIds
      class Error < StandardError ; end

      attr_reader :ids
      def initialize(spec_string)
        @ids = []
        begin
          parse_spec_string(spec_string) if spec_string
        rescue Error
        end
      end

      protected
      def parse_spec_string(spec_string)
        @ids = get_components(spec_string).map{
          |component| process_component(component)
        }.reduce(:+).sort
      end

      def get_components(spec_string)
        base = discard_percent_modifier(spec_string)
        raise Error unless base
        base.split(',')
      end

      # A few adapters use percent to define an arrays maximum number of
      # simultaneous tasks. The percent is expected to come at the end.
      def discard_percent_modifier(spec_string)
        spec_string.split('%').first
      end

      def process_component(component)
        if is_range?(component)
          get_range(component)
        elsif numbers_valid?([component])
          [ component.to_i ]
        else
          raise Error
        end
      end

      def get_range(component)
        raw_range, raw_step = component.split(':')
        start, stop = raw_range.split('-')
        raise Error unless numbers_valid?(
          # Only include Step if it is not nil
          [start, stop].tap { |a| a << raw_step if raw_step }
        )
        range = Range.new(start.to_i, stop.to_i)
        step = raw_step.to_i
        step = 1 if step == 0

        range.step(step).to_a
      end

      def is_range?(component)
        component.include?('-')
      end

      # Protect against Ruby's String#to_i returning 0 for arbitrary strings
      def numbers_valid?(numbers)
        numbers.all? { |str| /^[0-9]+$/ =~ str }
      end
    end
  end
end
