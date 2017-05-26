require "ood_core/refinements/hash_extensions"

module OodCore
  module BatchConnect
    class Factory
      using Refinements::HashExtensions

      # Build the basic template from a configuration
      # @param config [#to_h] the configuration for the batch connect template
      def self.build_basic(config)
        context = config.to_h.symbolize_keys.reject { |k, _| k == :template }
        Templates::Basic.new(context)
      end
    end

    module Templates
      # A batch connect template that expects to start up a basic web server
      # within a batch job
      class Basic < Template
      end
    end
  end
end
