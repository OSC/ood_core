module OodCore
  module Job
    # An object that describes the current state of a submitted job
    class Status
      class << self
        # Possible states a submitted job can be in:
        #   # Job status cannot be determined
        #   :undetermined
        #
        #   # Job is queued for being scheduled and executed
        #   :queued
        #
        #   # Job has been placed on hold by the system, the administrator, or
        #   # submitting user
        #   :queued_held
        #
        #   # Job is running on an execution host
        #   :running
        #
        #   # Job has been suspended by the user, the system, or the administrator
        #   :suspended
        #
        #   # Job is completed and not running on an execution host
        #   :completed
        def states
          %i(
            undetermined
            queued
            queued_held
            running
            suspended
            completed
          )
        end
      end

      # Current status of submitted job
      # @return [Symbol] status of job
      attr_reader :state

      # @param state [#to_sym] status of job
      # @raise [UnknownStateAttribute] if supplied state does not exist
      def initialize(state:, **_)
        @state = state.to_sym
        raise UnknownStateAttribute, "arguments specify unknown '#{@state}' state" unless self.class.states.include?(@state)
      end

      # Convert object to symbol
      # @return [Symbol] object as symbol
      def to_sym
        state
      end

      # Convert object to string
      # @return [String] object as string
      def to_s
        state.to_s
      end

      # The comparison operator
      # @param other [#to_sym] object to compare against
      # @return [Boolean] whether objects are equivalent
      def ==(other)
        to_sym == other.to_sym
      end

      # Whether objects are identical to each other
      # @param other [#to_sym] object to compare against
      # @return [Boolean] whether objects are identical
      def eql?(other)
        self.class == other.class && self == other
      end

      # Generate a hash value for this object
      # @return [Fixnum] hash value of object
      def hash
        [self.class, to_sym].hash
      end

      # @!method undetermined?
      #   Whether the status is undetermined
      #   @return [Boolean] whether undetermined
      #
      # @!method queued?
      #   Whether the status is queued
      #   @return [Boolean] whether queued
      #
      # @!method queued_held?
      #   Whether the status is queued_held
      #   @return [Boolean] whether queued_held
      #
      # @!method running?
      #   Whether the status is running
      #   @return [Boolean] whether running
      #
      # @!method suspended?
      #   Whether the status is suspended
      #   @return [Boolean] whether suspended
      #
      # @!method completed?
      #   Whether the status is completed
      #   @return [Boolean] whether completed
      #
      # Determine whether this method corresponds to a status check for a valid
      # state. If so, then check whether this object is in that valid state.
      # @param method_name the method name called
      # @param arguments the arguments to the call
      # @param block an optional block for the call
      # @raise [NoMethodError] if method name doesn't pass checks
      # @return [Boolean] whether it is in this state
      def method_missing(method_name, *arguments, &block)
        if /^(?<other_state>.+)\?$/ =~ method_name && self.class.states.include?(other_state.to_sym)
          self == other_state
        else
          super
        end
      end

      # Determines whether this method corresponds to a status check for a valid
      # state
      # @param method_name the method name called
      # @return [Boolean]
      def respond_to_missing?(method_name, include_private = false)
        /^(?<other_state>.+)\?$/ =~ method_name && self.class.states.include?(other_state.to_sym) || super
      end
    end
  end
end
