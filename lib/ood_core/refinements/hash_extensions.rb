module OodCore
  # Namespace for Ruby refinements
  module Refinements
    # This module provides refinements for manipulating the Ruby {Hash} class.
    # Some elements have been taken from Rails (https://github.com/rails/rails)
    # and it's LICENSE has been added as RAILS-LICENSE in the root directory of this project.
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

        # Return a hash with non `nil` values
        # @example
        #   { a: 1, b: nil, c: 3, d: nil }.compact
        #   # => {:a=>1, :c=>3}
        # @see https://apidock.com/rails/Hash/compact
        def compact
          self.select { |_, value| !value.nil? }
        end

        # Returns a new hash with +self+ and +other_hash+ merged recursively.
        #
        #   h1 = { a: true, b: { c: [1, 2, 3] } }
        #   h2 = { a: false, b: { x: [3, 4, 5] } }
        #
        #   h1.deep_merge(h2) # => { a: false, b: { c: [1, 2, 3], x: [3, 4, 5] } }
        #
        # Like with Hash#merge in the standard library, a block can be provided
        # to merge values:
        #
        #   h1 = { a: 100, b: 200, c: { c1: 100 } }
        #   h2 = { b: 250, c: { c1: 200 } }
        #   h1.deep_merge(h2) { |key, this_val, other_val| this_val + other_val }
        #   # => { a: 100, b: 450, c: { c1: 300 } }
        def deep_merge(other_hash, &block)
          dup.deep_merge!(other_hash, &block)
        end

        # Same as +deep_merge+, but modifies +self+.
        def deep_merge!(other_hash, &block)
          merge!(other_hash) do |key, this_val, other_val|
            if this_val.is_a?(Hash) && other_val.is_a?(Hash)
              this_val.deep_merge(other_val, &block)
            elsif block_given?
              block.call(key, this_val, other_val)
            else
              other_val
            end
          end
        end
      end
    end
  end
end
