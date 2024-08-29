# File: lib/slug_generator.rb

# Requirements:
#
# - always valid for arbitrary strings
# - no collisions



require 'digest'

module SlugGenerator
    ALPHANUM = (('a'..'z').to_a + ('A'..'Z').to_a + ('0'..'9').to_a).freeze
    ALPHANUM_LOWER = (('a'..'z').to_a + ('0'..'9').to_a).freeze
    LOWER_PLUS_HYPHEN = ALPHANUM_LOWER + ['-']
  
    #patterns  _do_not_ need to cover the length or start/end conditions,
    #which are handled separately
    OBJECT_PATTERN = /^[a-z0-9\.-]+$/
    LABEL_PATTERN = /^[a-z0-9\.-_]+$/i

    #match anything that's not lowercase alphanumeric (will be stripped, replace with '-')
    NON_ALPHANUM_PATTERN = /[^a-z0-9]+/
  
    #length of hash suffix
    HASH_LENGTH = 8

    class << self
    def is_valid_general(s, starts_with: nil, ends_with: nil, pattern: nil, min_length: nil, max_length: nil)
      return false if min_length && s.length < min_length
      return false if max_length && s.length > max_length
      return false if starts_with && !starts_with.include?(s[0])
      return false if ends_with && !ends_with.include?(s[-1])
      return false if pattern && !pattern.match?(s)
      true
    end
