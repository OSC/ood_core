module OodCore
  # Namespace for Ruby refinements
  module Refinements
    # This module provides refinements for manipulating the Ruby {Hash} class.
    module HashExtensions
      refine Hash do
        # Symbolize the keys in a {Hash}
        def symbolize_keys
          self.each_with_object({}) { |(k, v), h| h[k.to_sym] = v }
        end

        # Slices a hash to include only the given keys. Returns a hash
        # containing the given keys.
        # @example
        #   { a: 1, b: 2, c: 3, d: 4 }.slice(:a, :b)
        #   # => {:a=>1, :b=>2}
        # @see http://apidock.com/rails/Hash/slice
        def slice(*keys)
          keys.map! { |key| convert_key(key) } if respond_to?(:convert_key, true)
          keys.each_with_object(self.class.new) { |k, hash| hash[k] = self[k] if has_key?(k) }
        end
      end
    end
  end
end
