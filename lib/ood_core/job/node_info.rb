module OodCore
  module Job
    # An object that describes the resources used on a specific node
    class NodeInfo
      # The name of the host machine
      # @return [String] node name
      attr_reader :name

      # The number of procs reserved on the given machine
      # @return [Integer, nil] number of procs
      attr_reader :procs

      # @param name [#to_s] node name
      # @param procs [#to_i, nil] number of procs
      def initialize(name:, procs: nil, **_)
        @name  = name.to_s
        @procs = procs && procs.to_i
      end

      # Convert object to hash
      # @return [Hash] object as hash
      def to_h
        { name: name, procs: procs }
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
      # @return [Integer] hash value of object
      def hash
        [self.class, to_h].hash
      end
    end
  end
end
