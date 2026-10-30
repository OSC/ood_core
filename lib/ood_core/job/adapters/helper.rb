require 'shellwords'

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
        # @param ssh_port [#to_s, nil] the cluster's SSH port, see ssh_port_args
        #
        # @return cmd [String] command wrapped in ssh if submit_host is present
        # @return args [Array] command arguments including ssh_flags and original command
        def self.ssh_wrap(submit_host, cmd, cmd_args, strict_host_checking = true, env = {}, ssh_port: nil)
          return cmd, cmd_args if submit_host.to_s.empty?

          check_host = strict_host_checking ? "yes" : "no"
          
          # Have to OodCore::Job::Adapters::Helper.ssh_port_args instead of self.ssh_port_args due to test failure
          args = OodCore::Job::Adapters::Helper.ssh_port_args(ssh_port) + ['-o', 'BatchMode=yes',
                  '-o', 'UserKnownHostsFile=/dev/null', '-o', "StrictHostKeyChecking=#{check_host}", 
                  "#{submit_host}"]
          env.each { |key, value| args.push("export #{key}=#{Shellwords.escape(value.to_s)};") }

          return 'ssh', args + [cmd] + cmd_args.map { |arg| Shellwords.escape(arg.to_s) }
        end

        # Allows for Non-Standard Port usage in ssh commands
        # The cluster's ssh_port takes precedence over ENV["OOD_SSH_PORT"].
        # To set ENV["OOD_SSH_PORT"], add assignment in /etc/ood/config/nginx_stage.yml
        # @param port [#to_s, nil] the cluster's SSH port
        # @return [String, nil] the port, or nil if neither is set
        def self.ssh_port(port = nil)
          port = ENV["OOD_SSH_PORT"] if port.to_s.empty?
          port.to_s.empty? ? nil : port.to_i.to_s
        end

        # The SSH arguments for the port. Without a port, -p is left out so that
        # ssh uses the port from ssh_config (22 by default).
        # @param port [#to_s, nil] the cluster's SSH port
        # @return [Array<String>] ['-p', port] or []
        def self.ssh_port_args(port = nil)
          port = OodCore::Job::Adapters::Helper.ssh_port(port)
          port.nil? ? [] : ['-p', port]
        end

      end
    end
  end
end
