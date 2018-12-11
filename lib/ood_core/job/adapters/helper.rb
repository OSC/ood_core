module OodCore
  module Job
    module Adapters
      # @api private
      class Helper
        # Get the configured path to a command allowing overrides from bin_overrides
        # @param cmd [String] the desired command
        # @param bin_default [String] the default place to find cmd on the file system
        # @param bin_overrides [Hash<String, String>] commands associated with the full path to their replacement
        #   e.g. {'squeue' => '/usr/local/slurm/bin/squeue'}
        # @return [String] path to the configured command
        def self.bin_path(cmd, bin_default, bin_overrides)
          bin_overrides.fetch(cmd.to_s) { Pathname.new(bin_default.to_s).join(cmd.to_s).to_s }
        end
      end
    end
  end
end