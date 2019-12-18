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
      attr_reader :spec_string

      def initialize(spec_string)
        @spec_string = spec_string
      end

      def ids
        @ids ||= parse_spec_string(spec_string)
      end

      protected

      def parse_spec_string(spec_string)
        return [] unless spec_string

        rx = /^(\d+)-?(\d+)?:?(\d+)?%?\d*$/
        spec_string.split(',').reduce([]) do |ids, spec|
          if rx =~ spec
            start = ($1 || 1).to_i
            finish = ($2 || start).to_i
            step = ($3 || 1).to_i
            ids.concat (start..finish).step(step).to_a
          end

          ids
        end
      end
    end
  end
end
