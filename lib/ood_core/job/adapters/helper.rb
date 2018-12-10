module OodCore
  module Job
    module Adapters
      # @api private
      class Helper
        # Get the configured path to a command allowing overrides from bin_overrides
        # @param cmd [String] the desired command
        # @param std_bin [String] the default place to find that command
        # @param bin_overrides [Hash<String, String>] commands associated with the full path to their replacement
        #   e.g. {'squeue' => '/usr/local/slurm/bin/squeue'}
        # @return [String] path to the configured command
        def self.bin_path(cmd, std_bin, bin_overrides)
          bin_overrides.fetch(cmd.to_s) { std_bin.join(cmd.to_s).to_s }
        end
      end
    end
  end
end