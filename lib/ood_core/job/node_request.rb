require 'ood_core/refinements/array_extensions'

module OodCore
  module Job
    # An object that describes a request for a node when submitting a job
    class NodeRequest
      using Refinements::ArrayExtensions

      # Number of processors usable by job
      # @return [Fixnum, nil] number of procs
      attr_reader :procs

      # List of properties required by job
      # @return [Array<String>, nil] list of properties
      attr_reader :properties

      # @param procs [#to_i, nil] number of procs
      # @param properties [#to_s, Array<#to_s>, nil] list of properties
      def initialize(procs: nil, properties: nil, **_)
        @procs      = procs      && procs.to_i
        @properties = properties && Array.wrap(properties).map(&:to_s)
      end

      # Convert object to hash
      # @return [Hash] object as hash
      def to_h
        { procs: procs, properties: properties }
      end

      # The comparison operator
      # @param other [#to_h] object to compare against
      # @return [Boolean] whether objects are equivalent
      def ==(other)
        to_h == other.to_h
      end

      # Whether objects are identical to each other
      # @param other [#to_h] object to compare against
      # @return [Boolean] whether objects are identical
      def eql?(other)
        self.class == other.class && self == other
      end

      # Generate a hash value for this object
      # @return [Fixnum] hash value of object
      def hash
        [self.class, to_h].hash
      end
    end
  end
end
