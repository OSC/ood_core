module PBS
  class Conn
    attr_reader :conn_id

    def initialize(args = {})
      batch   = args[:batch]
      cluster = args[:cluster]
      @batch_config = BATCH_CONFIG.fetch(cluster, {}).fetch(batch, {}).clone
      @batch_config.merge!(args[:config] || {})
    end

    def batch_lib
      @batch_config[:lib]
    end

    def batch_server
      @batch_config[:server]
    end

    def batch_ppn
      @batch_config[:ppn]
    end

    def batch_module
      @batch_config[:module]
    end

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
