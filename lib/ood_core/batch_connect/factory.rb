require "ood_core/refinements/hash_extensions"

module OodCore
  module BatchConnect
    # A factory that builds a batch connect template object from a
    # configuration.
    class Factory
      using Refinements::HashExtensions

      class << self
        # Build a batch connect template from a configuration
        # @param config [#to_h] configuration describing batch connect template
        # @option config [#to_s] :template The batch connect template to use
        # @raise [TemplateNotSpecified] if no template is specified
        # @raise [TemplateNotFound] if the specified template does not exist
        # @return [Template] the batch connect template object
        def build(config)
          c = config.to_h.symbolize_keys

          template = c.fetch(:template) { raise TemplateNotSpecified, "batch connect configuration does not specify template" }.to_s

          path_to_template = "ood_core/batch_connect/templates/#{template}"
          begin
            require path_to_template
          rescue Gem::LoadError => e
            raise Gem::LoadError, "Specified '#{template}' for batch connect template, but the gem is not loaded."
          rescue LoadError => e
            raise LoadError, "Could not load '#{template}'. Make sure that that batch connect template in the configuration file is valid."
          end

          template_method = "build_#{template}"

          unless respond_to?(template_method)
            raise TemplateNotFound, "batch connect configuration specifies nonexistent #{template} template"
          end

          send(template_method, c)
        end
      end
    end
  end
end
