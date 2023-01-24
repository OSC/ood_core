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
        
        # Gets a command that submits command on another host via ssh
        # @param submit_host [String] where to submit the command
        # @param cmd [String] the desired command to execute on another host
        # @param cmd_args [Array] arguments to the command specified above
        # @param strict_host_checking [Bool] whether to use strict_host_checking
        # @param env [Hash] env variables to be set w/ssh
        #
        # @return cmd [String] command wrapped in ssh if submit_host is present
        # @return args [Array] command arguments including ssh_flags and original command
        def self.ssh_wrap(submit_host, cmd, cmd_args, strict_host_checking = true, env = {})
          return cmd, cmd_args if submit_host.to_s.empty?

          check_host = strict_host_checking ? "yes" : "no"
          args = ['-o', 'BatchMode=yes', '-o', 'UserKnownHostsFile=/dev/null', '-o', "StrictHostKeyChecking=#{check_host}", "#{submit_host}"]
          env.each{|key, value| args.push("export #{key}=#{value};")}

          return 'ssh', args + [cmd] + cmd_args
        end
      end
    end
  end
end
