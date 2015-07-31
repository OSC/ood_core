module PBS
  class Conn
    attr_reader :conn_id

    # Initialize the connection
    # 
    # @param [Hash] args the arguments to consstruct the connection
    # @option args [String] :batch the batch options
    # @option args [String] :cluster the cluster
    # @option args [String] :config config
    def initialize(args = {})
      batch   = args[:batch]
      cluster = args[:cluster]
      @batch_config = batch && cluster ? BATCH_CONFIG[cluster][batch] : {}
      @batch_config.merge!(args[:config] || {})
    end

    # Return the name of the torque library used by the connection.
    # 
    # @example Torque 2.4.10
    #   /usr/local/torque-2.4.10/lib/libtorque.so
    # @example Torque 4.2.8
    #   /usr/local/torque-4.2.8/lib/libtorque.so
    #  
    # @return [String] the name of the torque library used by the connection.
    def batch_lib
      @batch_config[:lib]
    end

    # Returns the batch server of the connection
    # 
    # @example Glenn
    #   opt-batch.osc.edu
    # @example Oakley  
    #   oak-batch.osc.edu:17001
    # @example Ruby
    #   ruby-batch.ten.osc.edu
    #   
    # @return [String] the batch server
    def batch_server
      @batch_config[:server]
    end

    # Returns the default ppn of the connection
    # 
    # @example Glenn/Compute 
    #   8
    # @example Glenn/Oxymoron
    #   1:glenn
    # @example Oakley/Compute
    #   12
    # @example Oakley/Oxymoron
    #   1:oakley
    # @example Ruby/Compute
    #   20
    #   
    # @return [String, Integer] the default ppn of the connection
    def batch_ppn
      @batch_config[:ppn]
    end

    # Returns the module used by the connection
    # 
    # @example Torque 2.4.10
    #   '. /etc/profile.d/modules-env.sh && module swap torque torque-2.4.10'
    # @example Torque 4.2.8/vis
    #   '. /etc/profile.d/modules-env.sh && module swap torque torque-4.2.8_vis'
    #   
    # @return [String] the module command used by the connection
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
    #   
    # @return [Integer] the connection id
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

    # Returns true if the connection id is not nil and is greater than zero.
    #
    # @return [Boolean] true if connected
    def connected?
      !@conn_id.nil? && @conn_id > 0
    end

  end
end
