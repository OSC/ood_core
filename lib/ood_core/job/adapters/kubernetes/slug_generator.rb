#!/usr/bin/env ruby

# File: lib/slug_generator.rb

# Requirements:
#
# - always valid for arbitrary strings
# - no collisions

require 'digest'

module SlugGenerator

    #Creates an array of alphanumeric characters ( lowercase,uppercase,digits) ALPHANUM
    #The .freeze method makes this array immutable (can't be modified after creation)
    ALPHANUM = (('a'..'z').to_a + ('A'..'Z').to_a + ('0'..'9').to_a).freeze
    ALPHANUM_LOWER = (('a'..'z').to_a + ('0'..'9').to_a).freeze

    # LOWER_PLUS_HYPHEN: An array of lowercase alphanumeric characters plus the hyphen
    #This constant is not frozen, so it could potentially be modified
    LOWER_PLUS_HYPHEN = ALPHANUM_LOWER + ['-']
  
    #patterns  _do_not_ need to cover the length or start/end conditions,
    #which are handled separately
    OBJECT_PATTERN =    /^[a-z0-9\-\.]+$/
    LABEL_PATTERN =     /^[a-z0-9\-_\.]+$/i
    NAMESPACE_PATTERN = /^[a-z0-9\-]+$/

    #match anything that's not lowercase alphanumeric (will be stripped, replace with '-')
    NON_ALPHANUM_PATTERN = /[^a-z0-9]+/
  
    #length of hash suffix
    HASH_LENGTH = 8

    class << self
    def valid_general?(s, starts_with: nil, ends_with: nil, pattern: nil, min_length: nil, max_length: nil)
      return false if min_length && s.length < min_length
      return false if max_length && s.length > max_length
      return false if starts_with && !starts_with.include?(s[0])
      return false if ends_with && !ends_with.include?(s[-1])
      return false if pattern && !pattern.match?(s)
      true
    end

    
    def valid_object_name?(s)
      valid_general?(
        s,
        starts_with: ALPHANUM_LOWER,
        ends_with:   ALPHANUM_LOWER,
        pattern:     OBJECT_PATTERN,
        max_length:  255,
        min_length:  1
      )
    end

    def valid_label?(s)
      return true if s.empty?
      valid_general?(
        s,
        starts_with: ALPHANUM,
        ends_with:   ALPHANUM,
        pattern:     LABEL_PATTERN,
        max_length:  63
      )
    end

    def valid_namespace_name?(s)
        return true if s.empty?
        valid_general?(
          s,
          starts_with: ALPHANUM_LOWER,
          ends_with:   ALPHANUM_LOWER,
          pattern:     NAMESPACE_PATTERN,
          max_length: 63,
        )
    end

    def valid_default?(s)
      valid_general?(
        s,
        starts_with: ALPHANUM_LOWER,
        ends_with:   ALPHANUM_LOWER,
        pattern:     OBJECT_PATTERN,
        min_length:  1,
        max_length:  63
      )
    end

    
    def extract_safe_name(name, max_length)
      #Convert the name to lower case and replace any alpha-numeric characters with a hyphen
      safe_name = name.downcase.gsub(NON_ALPHANUM_PATTERN, '-')

      #remove any leading or trailing hyphens
      safe_name = safe_name.gsub(/\A-+|-+\z/, '')

      #Truncate the name to the specified max_length
      safe_name = safe_name[0...max_length]

      #If the resulting name is empty, set it to 'x'
      safe_name = 'x' if safe_name.empty?

      #Return the safe name
      safe_name
    end

    def strip_and_hash(name, max_length: 32)

      #Calculate the available length for the name part  
      name_length = max_length - (HASH_LENGTH + 3)

      #Raise an errir if the resulting name would be too short
      raise ArgumentError, "Cannot make safe names shorter than #{HASH_LENGTH + 4}" if name_length < 1

      #Generate a hash of the original name and take the first HASH_LENGTH characters
      #Then createa Safe version of the name. Finally, combine the safe name and hash, separated by '---'
      name_hash = Digest::SHA256.hexdigest(name)[0...HASH_LENGTH]
      safe_name = extract_safe_name(name, name_length)
      "#{safe_name}---#{name_hash}"
    end

    def safe_slug(name, max_length: nil, &valid)

      #If the name contains '--', use strp_and_hash immediately
      return strip_and_hash(name, max_length: max_length || 32) if name.include?('--')

      #If the name is valid and within max_length, return it as is
      #Otherwise, use strrp_and_hash to create a safe slug
      if !block_given?
        valid = proc { |n| valid_default?(n) }
      end
      if valid.call(name) && (max_length.nil? || name.length <= max_length)
        name
      else
        strip_and_hash(name, max_length: max_length || 32)
      end
    end

    def multi_slug(names, max_length: 48)

      #Initialise a new SHA256 hash object 
      #add the first name to the hash
      hasher = Digest::SHA256.new
      hasher.update(names[0])

      #For each subsequent name, add a delimited (/xFF) and the name to the hash
      #This ensures unique hashes even if names contain the delimiter
      names[1..-1].each do |name|
        hasher.update("\xFF")
        hasher.update(name)
      end

      # Generate the final hash and truncate it to HASH_LENGTH characters
      hash = hasher.hexdigest[0...HASH_LENGTH]

      # Subtracting HASH_LENGTH + 1 to account for the hash and its separator
      #Divide available characters equally among all names
      available_chars = max_length - (HASH_LENGTH + 1)
      per_name = available_chars / names.length

      # Subtract 2 from per_name to account '--' separators between names
      name_max_length = per_name - 2

      raise ArgumentError, "Not enough characters for #{names.length} names: #{max_length}" if name_max_length < 2

      #Generate safe versions of each name, limited to name_max_length
      name_slugs = names.map { |name| extract_safe_name(name, name_max_length) }

      # Join the safe names with '--', then add '---' and the hash
      # This format ensures the result can be distinguished from single-name slugs
      "#{name_slugs.join('--')}---#{hash}"
    end
  end
end
