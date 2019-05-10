require "ood_core/refinements/array_extensions"
require "parslet"

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
      using Refinements::ArrayExtensions

      class ArraySpecParser < Parslet::Parser
        rule(:integer) { match('[0-9]').repeat(1) }
        # rule(:integer_gt_zero) { match('[1-9][0-9]*') }
        rule(:max_concurrent) { str('%') >> integer }
        rule(:range) { integer.as(:start) >> str('-') >> integer.as(:stop) }
        rule(:stepped_range) { range >> str(':') >> integer.as(:step) }
        rule(:component) { stepped_range | range | integer.as(:start) }
        rule(:additional_component) { str(',') >> component }
        rule(:array_spec) { component >> additional_component.repeat >> max_concurrent.maybe }
        root(:array_spec)
      end

      class ArraySpecComponent
        def initialize(start:, stop: nil, step: 1)
          @start = start.to_i
          @stop  = (stop) ? stop.to_i : nil
          @step  = step.to_i
        end

        def to_a
          (@stop) ? Range.new(@start, @stop).step(@step).to_a : [@start]
        end
      end

      def initialize(spec_string)
        @spec_string = spec_string
      end

      def ids
        Array.wrap(ArraySpecParser.new.parse(@spec_string)).map do |component|
          ArraySpecComponent.new(**component).to_a
        end.reduce(:+).sort
      rescue
        []
      end
    end
  end
end
