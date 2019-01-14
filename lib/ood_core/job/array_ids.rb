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
      attr_reader :ids
      def initialize(spec_string)
        @ids = []
        parse_spec_string(spec_string)
      end

      protected
      def parse_spec_string(spec_string)
        @ids = get_components(spec_string).map{
          |component| process_component(component)
        }.reduce(:+).sort
      end

      def get_components(spec_string)
        spec_string.split(',')
      end

      def process_component(component)
        is_range?(component) ? get_range(component) : [ component.to_i ]
      end

      def get_range(component)
        raw_range, raw_step = component.split(':')
        start, stop = raw_range.split('-').map(&:to_i)
        range = Range.new(start, stop)
        step = raw_step.to_i
        step = 1 if step == 0
        
        range.step(step).to_a
      end

      def is_range?(component)
        component.include?('-')
      end
    end
  end
end