module PBS
  class Conn
    attr_reader :conn_id, :batch

    # Initialize the connection
    #
    # @param [Hash] args the arguments to construct the connection
    # @option args [Batch] :batch the batch server to connect to
    def initialize(args = {})
      @batch   = args[:batch]
    end

    # Creates a torque connection
    #
    #   Resets the Torque module to the correct library
    #   Disconnects if there is already a connection
    #   Creates a PBS connection to the batch server
    #   Checks for errors
    #   Returns the connection id
    #
    # @return [Integer] the connection id
    def connect
      # Reset the Torque module to correct library when connecting
      # typically all commands will connect/do stuff/disconnect
      Torque.init lib: batch.lib

      # Disconnect if already connected
      disconnect if connected?

      # Connect
      @conn_id = Torque.pbs_connect(batch.server)

      # Check for any connection errors
      Torque.check_for_error

      # Output connection id
      @conn_id
    end

    # Disconnects from the connection and sets the connection id to nil.
    def disconnect
      # Disconnect if already connected
      Torque.pbs_disconnect(@conn_id) if connected?

      # Reset connection id
      @conn_id = nil
    end

    # Returns true if the connection id is not nil and is greater than zero.
    #
    # @return [Boolean] true if connected
    def connected?
      !@conn_id.nil? && @conn_id > 0
    end
  end
end
