module OodCore
  module Job
    # An object that describes a submitted job with extended information
    class ExtendedInfo < Info

      attr_reader :ood_connection_info

      def initialize(options = {})
        super(options)
      end
    end
  end
end