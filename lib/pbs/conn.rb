module PBS
  class Conn
    # @example Torque 4.2.8
    #   "/usr/local/torque-4.2.8/lib/libtorque.so"
    # @return [String] The torque library to use for connection.
    attr_reader :lib

    # @example Oakley
    #   "oak-batch.osc.edu"
    # @return [String] The batch server to connect to.
    attr_reader :server

    # @example Torque 4.2.8
    #   ". /etc/profile.d/modules-env.sh && module swap torque torque-4.2.8_vis"
    # @return [String] The module command used for calling command line torque.
    attr_reader :module

    # @return [Fixnum, nil] The connection id number if connected.
    attr_reader :conn_id

    # Create a new connection object from pre-defined batch server defined in
    # batch config yaml.
    # @example Create Oakley connection
    #   PBS::Conn.batch 'oakley'
    #
    # @param name [String] The name of the pre-defined batch server.
    # @param opts [Hash] The options to create a connection object with.
    # @option opts [String] :lib The torque library used to establish connection.
    # @option opts [String] :server The batch server to connect to.
    # @option opts [String] :module The module command to interface with the command line.
    # @raise [Error] if pre-defined batch server doesn't exist.
    def self.batch(name, opts = {})
      context = PBS.batch_config[name] || raise(PBS::Error, "No pre-defined batch server (#{name})")
      lib = opts[:lib]    || context['lib']
      svr = opts[:server] || context['server']
      mod = opts[:module] || context['module']
      Conn.new(lib: lib, server: svr, module: mod)
    end

    # @param opts [Hash] The options to create a connection object with.
    # @option opts [String] :lib The torque library used to establish connection.
    # @option opts [String] :server The batch server to connect to.
    # @option opts [String] :module The module command to interface with the command line.
    def initialize(opts)
      @lib    = opts[:lib]
      @server = opts[:server]
      @module = opts[:module]
    end

    # Creates a torque connection
    #
    # @return [Integer] The connection id.
    def connect
      Torque.init lib: lib          # reset library used in Torque
      disconnect if connected?      # clean up any old connection
      @conn_id = Torque.pbs_connect(server)
      Torque.check_for_error        # check for connection errors
      conn_id
    end

    # Disconnects from the connection and sets the connection id to nil.
    def disconnect
      Torque.pbs_disconnect(@conn_id)
      @conn_id = nil    # reset connection id
    end

    # Returns true if the connection id is not nil and is greater than zero.
    #
    # @return [Boolean] Are we connected?
    def connected?
      !@conn_id.nil? && @conn_id > 0
    end
  end
end
