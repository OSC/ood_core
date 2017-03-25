module OodCore
  # Namespace for Ruby refinements
  module Refinements
    # This module provides refinements for manipulating the Ruby {Hash} class.
    module HashExtensions
      # Symbolize the keys in a {Hash}
      refine Hash do
        def symbolize_keys
          self.each_with_object({}) { |(k, v), h| h[k.to_sym] = v }
        end
      end
    end
  end
end
