# frozen_string_literal: true

require 'ood_core/refinements/hash_extensions'

module OodCore
  module Files
    # A factory that builds files adapter objects from a configuration.
    class Factory
      using Refinements::HashExtensions

      require 'ood_core/files/adapters/ssh'

      class << self
        # Build a files adapter from a configuration
        # @param config [#to_h] configuration describing files adapter
        # @option config [#to_s] :adapter The files adapter to use, e.g. ssh for {Adapters::Ssh}
        # @raise [AdapterNotSpecified] if no adapter is specified
        # @raise [AdapterNotFound] if the specified adapter does not exist
        # @return [Adapter] the files adapter object
        def build(config)
          c = config.to_h.symbolize_keys

          adapter = c.fetch(:adapter) { raise AdapterNotSpecified, 'files configuration does not specify adapter' }.to_s

          adapter_class(adapter).new(**c.except(:adapter))
        end

        private

        def adapter_class(adapter)
          class_name = adapter.split(/[_-]/).map { |s| s.gsub(/\b\w/, &:upcase) }.join
          klass = Adapters.const_get(class_name, false)
          raise NameError unless klass.is_a?(Class) && klass < Adapter

          klass
        rescue NameError
          raise AdapterNotFound, "files configuration specifies nonexistent #{adapter} adapter"
        end
      end
    end
  end
end
