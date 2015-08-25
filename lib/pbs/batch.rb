module PBS
  class Batch
    # Initialize the batch server.
    #
    # @param [Hash] args the arguments to construct the connection
    # @option args [String] :name the batch to connect to (see config/batch.yml)
    # @option args [String] :lib the torque library used to connect
    # @option args [String] :server the batch server to connect to
    # @option args [String] :module the OSC module with the torque library
    def initialize(args = {})
      @batch_config = {}
      @batch_config[:name] = args[:name]
      @batch_config = BATCH_CONFIG.fetch(name, {}).clone

      # Merge the arguments into this hash
      @batch_config.merge!(args)
    end

    # Return the name of this batch object if supplied
    #
    # @return [String] the name of this batch object ('glenn', 'oakley', 'ruby', 'oxymoron')
    def name
      @batch_config[:name]
    end

    # Return the name of the torque library used by the connection.
    #
    # @example Torque 2.4.10
    #   /usr/local/torque-2.4.10/lib/libtorque.so
    # @example Torque 4.2.8
    #   /usr/local/torque-4.2.8/lib/libtorque.so
    #
    # @return [String] the name of the torque library used by the connection.
    def lib
      @batch_config[:lib]
    end

    # Returns the batch server of the connection.
    #
    # @example Glenn
    #   opt-batch.osc.edu
    # @example Oxymoron
    #   oak-batch.osc.edu:17001
    # @example Ruby
    #   ruby-batch.ten.osc.edu
    #
    # @return [String] the batch server
    def server
      @batch_config[:server]
    end

    # Returns the module used by the connection.
    #
    # @example Torque 2.4.10
    #   '. /etc/profile.d/modules-env.sh && module swap torque torque-2.4.10'
    # @example Torque 4.2.8/vis
    #   '. /etc/profile.d/modules-env.sh && module swap torque torque-4.2.8_vis'
    #
    # @return [String] the module command used by the connection
    def module
      @batch_config[:module]
    end
  end
end
