require 'yaml'

module PBS
  class Conn
    attr_reader :conn_id
    attr_reader :lib
    attr_reader :server

    def initialize(args = {})
      @lib = args[:lib]
      @server = args[:server]

      # Get lib and server from user specified cluster/batch
      cluster = args[:cluster]
      batch = args[:batch]
      batch_config = YAML.load_file("#{CONFIG_PATH}/batch.yml")
      @lib ||= batch_config[cluster][batch]['lib']
      @server ||= batch_config[cluster][batch]['server']
    end

    def connect
      # Reset the Torque module to correct library when connecting
      # typically all commands will connect/do stuff/disconnect
      Torque.init lib: lib

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
