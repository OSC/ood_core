require "ood_core/refinements/hash_extensions"
require "ood_core/refinements/array_extensions"
require "ood_core/job/adapters/helper"
require 'json'

module OodCore
  module Job
    class Factory
      using Refinements::HashExtensions

      # Build the Slurm adapter from a configuration
      # @param config [#to_h] the configuration for job adapter
      # @option config [Object] :cluster (nil) The cluster to communicate with
      # @option config [Object] :conf (nil) Path to the slurm conf
      # @option config [Object] :bin (nil) Path to slurm client binaries
      # @option config [#to_h] :bin_overrides ({}) Optional overrides to Slurm client executables
      def self.build_singularity(config)
        c = config.to_h.symbolize_keys
        hosts = c.fetch(:hosts, {})
        Adapters::Singularity.new(
          hosts: hosts
        )
      end
    end

    module Adapters
      # A class that handles the communication with a resource manager for
      # submitting/statusing/holding/deleting jobs
      # @abstract
      class Singularity < Adapter
        using Refinements::ArrayExtensions

        class Instance
          def initialize(hosts)
            @username = Etc.getlogin
            @hosts = hosts
          end

          def start(hostname: 'localhost', image:, instance:)
            cmd = ssh_cmd(hostname) + [
              singularity_cmd(hostname), 'instance', 'start', image.to_s, instance
            ]

            call(*cmd)

            "#{instance}@#{hostname}"
          end

          # Stop a Singularity container
          def stop(hostname: 'localhost', all: false, signal: nil, instance: nil)
            cmd = ssh_cmd(hostname) + [
              singularity_cmd(hostname), 'instance', 'stop'
            ]

            cmd << '--all' if all && ! instance
            cmd += ['--signal', signal] if signal
            cmd << instance if instance

            call(*cmd)
          rescue  # Do not throw if the job is not found
          end

          # List the current user's instances
          # 
          # Note that while a --user flag does exist it is privileged
          # @return Array<Hash> Singularity instances running
          def list(hostname: 'localhost')
            cmd = ssh_cmd(hostname) + [
              singularity_cmd(hostname), 'instance', 'list', '--json'
            ]

            JSON.parse(call(*cmd))['instances']
          end

          private

          # Call a forked Slurm command for a given cluster
          def call(cmd, *args, env: {}, stdin: "")
            args  = args.map(&:to_s)
            env = env.to_h
            o, e, s = Open3.capture3(env, cmd, *args, stdin_data: stdin.to_s)
            s.success? ? o : raise(Error, e)
          end

          def ssh_cmd(hostname)
            ['ssh', "#{@username}@#{hostname}", '-o', 'BatchMode=yes']
          end

          def singularity_cmd(hostname)
            @hosts.fetch(hostname, 'singularity')
          end
        end

        def initialize(hosts:)
          @hosts = hosts
        end

        # Submit a job with the attributes defined in the job template instance
        # @abstract Subclass is expected to implement {#submit}
        # @raise [NotImplementedError] if subclass did not define {#submit}
        # @example Submit job template to cluster
        #   solver_id = job_adapter.submit(solver_script)
        #   #=> "1234.server"
        # @example Submit job that depends on previous job
        #   post_id = job_adapter.submit(
        #     post_script,
        #     afterok: solver_id
        #   )
        #   #=> "1235.server"
        # @param script [Script] script object that describes the
        #   script and attributes for the submitted job
        # @param after [#to_s, Array<#to_s>] this job may be scheduled for execution
        #   at any point after dependent jobs have started execution
        # @param afterok [#to_s, Array<#to_s>] this job may be scheduled for
        #   execution only after dependent jobs have terminated with no errors
        # @param afternotok [#to_s, Array<#to_s>] this job may be scheduled for
        #   execution only after dependent jobs have terminated with errors
        # @param afterany [#to_s, Array<#to_s>] this job may be scheduled for
        #   execution after dependent jobs have terminated
        # @return [String] the job id returned after successfully submitting a job
        def submit(script, after: [], afterok: [], afternotok: [], afterany: [])
          raise NotImplementedError, "subclass did not define #submit"
        end

        # Retrieve info for all jobs from the resource manager
        # @abstract Subclass is expected to implement {#info_all}
        # @raise [NotImplementedError] if subclass did not define {#info_all}
        # @param attrs [Array<symbol>] defaults to nil (and all attrs are provided) 
        #   This array specifies only attrs you want, in addition to id and status.
        #   If an array, the Info object that is returned to you is not guarenteed
        #   to have a value for any attr besides the ones specified and id and status.
        #
        #   For certain adapters this may speed up the response since
        #   adapters can get by without populating the entire Info object
        # @return [Array<Info>] information describing submitted jobs
        def info_all(attrs: nil)
          raise NotImplementedError, "subclass did not define #info_all"
        end

        # Retrieve info for all jobs for a given owner or owners from the
        # resource manager
        # @param owner [#to_s, Array<#to_s>] the owner(s) of the jobs
        # @param attrs [Array<symbol>] defaults to nil (and all attrs are provided) 
        #   This array specifies only attrs you want, in addition to id and status.
        #   If an array, the Info object that is returned to you is not guarenteed
        #   to have a value for any attr besides the ones specified and id and status.
        #
        #   For certain adapters this may speed up the response since
        #   adapters can get by without populating the entire Info object
        # @return [Array<Info>] information describing submitted jobs
        def info_where_owner(owner, attrs: nil)
          owner = Array.wrap(owner).map(&:to_s)

          # must at least have job_owner to filter by job_owner
          attrs = Array.wrap(attrs) | [:job_owner] unless attrs.nil?

          info_all(attrs: attrs).select { |info| owner.include? info.job_owner }
        end

        # Iterate over each job Info object
        # @param attrs [Array<symbol>] defaults to nil (and all attrs are provided) 
        #   This array specifies only attrs you want, in addition to id and status.
        #   If an array, the Info object that is returned to you is not guarenteed
        #   to have a value for any attr besides the ones specified and id and status.
        #
        #   For certain adapters this may speed up the response since
        #   adapters can get by without populating the entire Info object
        # @yield [Info] of each job to block
        # @return [Enumerator] if no block given
        def info_all_each(attrs: nil)
          return to_enum(:info_all_each, attrs: attrs) unless block_given?

          info_all(attrs: attrs).each do |job|
            yield job
          end
        end

        # Iterate over each job Info object
        # @param owner [#to_s, Array<#to_s>] the owner(s) of the jobs
        # @param attrs [Array<symbol>] defaults to nil (and all attrs are provided) 
        #   This array specifies only attrs you want, in addition to id and status.
        #   If an array, the Info object that is returned to you is not guarenteed
        #   to have a value for any attr besides the ones specified and id and status.
        #
        #   For certain adapters this may speed up the response since
        #   adapters can get by without populating the entire Info object
        # @yield [Info] of each job to block
        # @return [Enumerator] if no block given
        def info_where_owner_each(owner, attrs: nil)
          return to_enum(:info_where_owner_each, owner, attrs: attrs) unless block_given?

          info_where_owner(owner, attrs: attrs).each do |job|
            yield job
          end
        end

        # Whether the adapter supports job arrays
        # @return [Boolean] - assumes true; but can be overridden by adapters that
        #   explicitly do not
        def supports_job_arrays?
          true
        end

        # Retrieve job info from the resource manager
        # @abstract Subclass is expected to implement {#info}
        # @raise [NotImplementedError] if subclass did not define {#info}
        # @param id [#to_s] the id of the job
        # @return [Info] information describing submitted job
        def info(id)
          raise NotImplementedError, "subclass did not define #info"
        end

        # Retrieve job status from resource manager
        # @note Optimized slightly over retrieving complete job information from server
        # @abstract Subclass is expected to implement {#status}
        # @raise [NotImplementedError] if subclass did not define {#status}
        # @param id [#to_s] the id of the job
        # @return [Status] status of job
        def status(id)
          raise NotImplementedError, "subclass did not define #status"
        end

        # Put the submitted job on hold
        # @abstract Subclass is expected to implement {#hold}
        # @raise [NotImplementedError] if subclass did not define {#hold}
        # @param id [#to_s] the id of the job
        # @return [void]
        def hold(id)
          raise NotImplementedError, "subclass did not define #hold"
        end

        # Release the job that is on hold
        # @abstract Subclass is expected to implement {#release}
        # @raise [NotImplementedError] if subclass did not define {#release}
        # @param id [#to_s] the id of the job
        # @return [void]
        def release(id)
          raise NotImplementedError, "subclass did not define #release"
        end

        # Delete the submitted job
        # @abstract Subclass is expected to implement {#delete}
        # @raise [NotImplementedError] if subclass did not define {#delete}
        # @param id [#to_s] the id of the job
        # @return [void]
        def delete(id)
          raise NotImplementedError, "subclass did not define #delete"
        end
      end
    end
  end
end
