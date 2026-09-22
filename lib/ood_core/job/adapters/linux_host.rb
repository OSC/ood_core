require "ood_core/refinements/hash_extensions"
require "ood_core/refinements/array_extensions"
require "ood_core/job/adapters/helper"
require "set"

module OodCore
  module Job
    class Factory
      using Refinements::HashExtensions

      # Build the LinuxHost adapter from a configuration
      # @param config [#to_h] the configuration for job adapter
      # @option config [Object] :contain (false) Pass `--contain` flag to Singularity; allows overriding bind mounts in singularity.conf
      # @option config [Object] :debug (false) Use the adapter in a debug mode
      # @option config [Object] :max_timeout (nil) The longest 'wall_clock' permissible
      # @option config [Object] :singularity_bin ('/usr/bin/singularity') The path to the Singularity executable
      # @option config [Object] :singularity_bindpath ('/etc,/media,/mnt,/opt,/srv,/usr,/var,/users') A comma delimited list of paths to bind between the host and the guest
      # @option config [Object] :singularity_image The path to the Singularity image to use
      # @option config [Object] :ssh_hosts (nil) The list of permissable hosts, defaults to :submit_host
      # @option config [Object] :strict_host_checking (true) Set to false to disable strict host checking and updating the known_hosts file
      # @option config [Object] :submit_host The SSH target to connect to, may be the head of a round-robin
      # @option config [Object] :tmux_bin ('/usr/bin/tmux') The path to the Tmux executable
      def self.build_linux_host(config)
        c = config.to_h.symbolize_keys
        contain = c.fetch(:contain, false)
        debug = c.fetch(:debug, false)
        max_timeout = c.fetch(:max_timeout, nil)
        singularity_bin = c.fetch(:singularity_bin, '/usr/bin/singularity')
        singularity_bindpath = c.fetch(:singularity_bindpath, '/etc,/media,/mnt,/opt,/srv,/usr,/var,/users')
        singularity_image = c[:singularity_image]
        ssh_hosts = c.fetch(:ssh_hosts, [c[:submit_host]])
        strict_host_checking = c.fetch(:strict_host_checking, true)
        submit_host = c[:submit_host]
        tmux_bin = c.fetch(:tmux_bin, '/usr/bin/tmux')

        Adapters::LinuxHost.new(
          ssh_hosts: ssh_hosts,
          launcher: Adapters::LinuxHost::Launcher.new(
            contain: contain,
            debug: debug,
            max_timeout: max_timeout,
            singularity_bin: singularity_bin,
            singularity_bindpath: singularity_bindpath,  # '/etc,/media,/mnt,/opt,/srv,/usr,/var,/users',
            singularity_image: singularity_image,
            ssh_hosts: ssh_hosts,
            strict_host_checking: strict_host_checking,
            submit_host: submit_host,
            tmux_bin: tmux_bin,
          )
        )
      end
    end

    module Adapters
      # An adapter object that describes the communication with a remote host
      # for job management.
      class LinuxHost < Adapter
        using Refinements::ArrayExtensions

        require "ood_core/job/adapters/linux_host/launcher"

        def initialize(ssh_hosts:, launcher:)
          @launcher = launcher
          @ssh_hosts = Set.new(ssh_hosts)
        end

        # Submit a job with the attributes defined in the job template instance
        # @param script [Script] script object that describes the script and
        #   attributes for the submitted job
        # @param after [#to_s, Array<#to_s>] No scheduling is available is used; setting raises JobAdapterError
        # @param afterok [#to_s, Array<#to_s>] No scheduling is available is used; setting raises JobAdapterError
        # @param afternotok [#to_s, Array<#to_s>] No scheduling is available is used; setting raises JobAdapterError
        # @param afterany [#to_s, Array<#to_s>] No scheduling is available is used; setting raises JobAdapterError
        # @raise [JobAdapterError] if something goes wrong submitting a job
        # @return [String] the job id returned after successfully submitting a
        #   job
        # @see Adapter#submit
        def submit(script, after: [], afterok: [], afternotok: [], afterany: [])
          unless (after.empty? && afterok.empty? && afternotok.empty? && afterany.empty?)
            raise JobAdapterError, 'Scheduling subsequent jobs is not available.'
          end

          @launcher.start_remote_session(script)
        rescue Launcher::Error => e
          raise JobAdapterError, e.message
        end

        # Retrieve info for all jobs from the resource manager
        # @raise [JobAdapterError] if something goes wrong getting job info
        # @return [Array<Info>] information describing submitted jobs
        # @see Adapter#info_all
        def info_all(attrs: nil, host: nil)
          host_permitted?(host) if host

          @launcher.list_remote_sessions(host: host).map{
            |ls_output| ls_to_info(ls_output)
          }
        rescue Launcher::Error => e
          raise JobAdapterError, e.message
        end

        # Retrieve info for all jobs for a given owner or owners from the
        # resource manager
        # Note: owner and attrs are present only to complete the interface and are ignored
        # Note: since this API is used in production no errors or warnings are thrown / issued
        # @param owner [#to_s, Array<#to_s>] the owner(s) of the jobs
        # @raise [JobAdapterError] if something goes wrong getting job info
        # @return [Array<Info>] information describing submitted jobs
        def info_where_owner(_, attrs: nil)
          info_all
        end

        # Iterate over each job Info object
        # @param attrs [Array<symbol>] attrs is present only to complete the interface and is ignored
        # @yield [Info] of each job to block
        # @return [Enumerator] if no block given
        def info_all_each(attrs: nil)
          return to_enum(:info_all_each, attrs: attrs) unless block_given?

          info_all(attrs: attrs).each do |job|
            yield job
          end
        end

        # Iterate over each job Info object
        # @param owner [#to_s, Array<#to_s>] owner is present only to complete the interface and is ignored
        # @param attrs [Array<symbol>] attrs is present only to complete the interface and is ignored
        # @yield [Info] of each job to block
        # @return [Enumerator] if no block given
        def info_where_owner_each(owner, attrs: nil)
          return to_enum(:info_where_owner_each, owner, attrs: attrs) unless block_given?

          info_where_owner(owner, attrs: attrs).each do |job|
            yield job
          end
        end

        # Whether the adapter supports job arrays
        # @return [Boolean] - false
        def supports_job_arrays?
          false
        end

        # Retrieve job info from the SSH host
        # @param id [#to_s] the id of the job
        # @raise [JobAdapterError] if something goes wrong getting job info
        # @return [Info] information describing submitted job
        # @see Adapter#info
        def info(id)
          _, host = parse_job_id(id)
          job = info_all(host: host).select{|info| info.id == id}.first
          (job) ? job : Info.new(id: id, status: :completed)
        rescue Launcher::Error => e
          raise JobAdapterError, e.message
        end

        # Retrieve job status from resource manager
        # @note Optimized slightly over retrieving complete job information from server
        # @abstract Subclass is expected to implement {#status}
        # @raise [NotImplementedError] if subclass did not define {#status}
        # @param id [#to_s] the id of the job
        # @return [Status] status of job
        def status(id)
          _, host = parse_job_id(id)
          job = info_all(host: host).select{|info| info.id == id}.first

          Status.new(state: (job) ? :running : :completed)
        rescue Launcher::Error => e
          raise JobAdapterError, e.message
        end

        # Put the submitted job on hold
        # @abstract Subclass is expected to implement {#hold}
        # @raise [NotImplementedError] if subclass did not define {#hold}
        # @param id [#to_s] the id of the job
        # @return [void]
        def hold(id)
          # Consider sending SIGSTOP?
          raise NotImplementedError, "subclass did not define #hold"
        end

        # Release the job that is on hold
        # @abstract Subclass is expected to implement {#release}
        # @raise [NotImplementedError] if subclass did not define {#release}
        # @param id [#to_s] the id of the job
        # @return [void]
        def release(id)
          # Consider sending SIGCONT
          raise NotImplementedError, "subclass did not define #release"
        end

        # Delete the submitted job
        # @abstract Subclass is expected to implement {#delete}
        # @raise [NotImplementedError] if subclass did not define {#delete}
        # @param id [#to_s] the id of the job
        # @return [void]
        def delete(id)
          session_name, destination_host = parse_job_id(id)
          @launcher.stop_remote_session(session_name, destination_host)
        rescue Launcher::Error => e
          raise JobAdapterError, e.message
        end

        def directive_prefix
          nil
        end

        private

        def host_permitted?(destination_host)
          raise JobAdapterError, "Requested destination host (#{destination_host}) not permitted" unless @ssh_hosts.include?(destination_host)
        end

        def parse_job_id(id)
          raise JobAdapterError, "#{id} is not a valid LinuxHost adapter id because it is missing the '@'." unless id.include?('@')

          return id.split('@')
        end

        # Convert the returned Hash into an Info object
        def ls_to_info(ls_output)
          started = ls_output[:session_created].to_i
          now = Time.now.to_i
          ellapsed = now - started
          Info.new(
              accounting_id: nil,
              allocated_nodes: [NodeInfo.new(name: ls_output[:destination_host], procs: 1)],
              cpu_time: ellapsed,
              dispatch_time: started,
              id: ls_output[:id],
              job_name: nil,  # TODO
              job_owner: Etc.getlogin,
              native: ls_output,
              procs: 1,
              queue_name: "LinuxHost adapter for #{@submit_host}",
              status: :running,
              submission_time: ellapsed,
              submit_host: @submit_host,
              wallclock_time: ellapsed
          )
        end
      end
    end
  end
end
