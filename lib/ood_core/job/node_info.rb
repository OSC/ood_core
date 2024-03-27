module OodCore
  module Job
    # An object that describes the resources used on a specific node.
    class NodeInfo
      # The name of the host machine
      # @return [String] node name
      attr_reader :name

      # The number of procs reserved on the given machine
      # @return [Integer, nil] number of procs
      attr_reader :procs

      # The features associated with this node.
      # @return [Array<String>, []]
      attr_reader :features

      # @param name [#to_s] node name
      # @param procs [#to_i, nil] number of procs
      # @param features [#to_a, []] list of features
      def initialize(name:, procs: nil, features: [], **_)
        @name  = name.to_s
        @procs = procs && procs.to_i
        @features = features.to_a
      end

      # Convert object to hash
      # @return [Hash] object as hash
      def to_h
        instance_variables.map do |var|
          name = var.to_s.gsub('@', '').to_sym
          [name, send(name)]
        end.to_h
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
