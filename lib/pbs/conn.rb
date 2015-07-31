module PBS
  class Conn
    attr_reader :conn_id

    # Initialize the connection
    # 
    # Args:
    #   args[:batch]
    #   args[:cluster]
    #   args[:config]
    def initialize(args = {})
      batch   = args[:batch]
      cluster = args[:cluster]
      @batch_config = batch && cluster ? BATCH_CONFIG[cluster][batch] : {}
      @batch_config.merge!(args[:config] || {})
    end

    # Return the name of the torque library used by the connection.
    # 
    # Examples:
    #   /usr/local/torque-2.4.10/lib/libtorque.so
    #   /usr/local/torque-4.2.8/lib/libtorque.so
    def batch_lib
      @batch_config[:lib]
    end

    # Returns the batch server of the connection
    # 
    # Examples:
    #   opt-batch.osc.edu
    #   oak-batch.osc.edu:17001
    #   ruby-batch.ten.osc.edu
    def batch_server
      @batch_config[:server]
    end

    # Returns the processors per node of the connection
    # 
    # Examples:
    #   1:glenn
    #   8
    #   12
    #   20
    def batch_ppn
      @batch_config[:ppn]
    end

    # Returns the module used by the connection
    # 
    # Examples:
    #   '. /etc/profile.d/modules-env.sh && module swap torque torque-2.4.10'
    #   '. /etc/profile.d/modules-env.sh && module swap torque torque-4.2.8_vis'
    def batch_module
      @batch_config[:module]
    end

    # Creates a torque connection
    # 
    #   Resets the Torque module to the correct library
    #   Disconnects if there is already a connection
    #   Creates a PBS connection to the batch server
    #   Checks for errors
    #   Returns the connection id
    def connect
      # Reset the Torque module to correct library when connecting
      # typically all commands will connect/do stuff/disconnect
      Torque.init lib: batch_lib

      # Disconnect if already connected
      disconnect if connected?

      # Connect
      @conn_id = Torque.pbs_connect(batch_server)

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

    # Returns true if the connection id is not null and is greater than zero.
    def connected?
      !@conn_id.nil? && @conn_id > 0
    end

  end
end
