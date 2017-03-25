require "ood_core/refinements/hash_extensions"

module OodCore
  module Job
    # A factory that builds job adapter objects from a configuration.
    class Factory
      using Refinements::HashExtensions

      class << self
        # Build a job adapter from a configuration
        # @param config [#to_h] configuration describing job adapter
        # @option config [#to_s] :adapter The job adapter to use
        # @raise [AdapterNotSpecified] if no adapter is specified
        # @raise [AdapterNotFound] if the specified adapter does not exist
        # @return [Adapter] the job adapter object
        def build(config)
          c = config.to_h.symbolize_keys

          adapter = c.fetch(:adapter) { raise AdapterNotSpecified, "job configuration does not specify adapter" }.to_s

          path_to_adapter = "ood_core/job/adapters/#{adapter}"
          begin
            require path_to_adapter
          rescue Gem::LoadError => e
            raise Gem::LoadError, "Specified '#{adapter}' for job adapter, but the gem is not loaded."
          rescue LoadError => e
            raise LoadError, "Could not load '#{adapter}'. Make sure that the job adapter in the configuration file is valid."
          end

          adapter_method = "build_#{adapter}"

          unless respond_to?(adapter_method)
            raise AdapterNotFound, "job configuration specifies nonexistent #{adapter} adapter"
          end

          send(adapter_method, c)
        end
      end
    end
  end
end
