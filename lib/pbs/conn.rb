module PBS
  class Conn
    attr_reader :conn_id
    attr_reader :server

    def initialize(args = {})
      Torque.init args
      @server = args[:server] || Torque.pbs_default
    end

    def connect
      # Disconnect if already connected
      disconnect if connected?

      # Connect
      @conn_id = Torque.pbs_connect(server)

      # Check for any connection errors
      Torque.check_for_error

      # Output connection id
      @conn_id
    end

    def disconnect
      # Disconnect if already connected
      Torque.pbs_disconnect(@conn_id) if connected?

      # Reset connection id
      @conn_id = nil
    end

    def connected?
      !@conn_id.nil? && @conn_id > 0
    end

  end
end
