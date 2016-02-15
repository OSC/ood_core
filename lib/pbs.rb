require 'yaml'

require_relative 'pbs/error'
require_relative 'pbs/attributes'
require_relative 'pbs/torque'
require_relative 'pbs/conn'
require_relative 'pbs/query'
require_relative 'pbs/job'
require_relative 'pbs/version'

module PBS
    # Path to the batch config yaml file describing the batch servers for
    # local batch schedulers.
    # @return [String] Path to the batch config yaml file.
    def self.default_batch_config_path
      default_config = File.expand_path("../../config/batch.yml", __FILE__)
      host_config = File.expand_path("../../config/#{Socket.gethostname}.yml", __FILE__)
      File.file?(host_config) ? host_config : default_config
    end

    # Set the path to the batch config yaml file.
    # @param path [String] The path to the batch config yaml file.
    def self.batch_config_path
      @batch_config_path ||= self.default_batch_config_path
    end

    # Hash generated from reading the batch config yaml file.
    # @return [Hash] Batch configuration generated from config yaml file.
    def self.batch_config
      YAML.load_file(batch_config_path)
    end
end
