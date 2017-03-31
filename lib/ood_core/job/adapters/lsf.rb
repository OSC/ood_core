        require "ood_core/refinements/hash_extensions"

module OodCore
  module Job
    class Factory
      using Refinements::HashExtensions

      # Build the Lsf adapter from a configuration
      # @param config [#to_h] the configuration for job adapter
      # @option config [#to_s] :host The batch server host
      # @option config [#to_s] :lib ('') Path to lsf client libraries
      # @option config [#to_s] :bin ('') Path to lsf client binaries
      def self.build_lsf(config)
        c = config.to_h.symbolize_keys
        Adapters::Lsf.new(c)
      end
    end

    module Adapters
      class Lsf < Adapter
        attr_reader :lib, :bin

        # Object used for simplified communication with a Slurm batch server
        class Batch
          # TODO:
          # attr_reader :cluster

          # The path to the LSF client installation binaries
          # @example For LSF 8.3
          #   my_batch.bin.to_s #=> "/opt/lsf/8.3/linux2.6-glibc2.3-x86_64/bin"
          # @return [Pathname] path to LSF binaries
          attr_reader :bin

          # The root exception class that all LSF-specific exceptions inherit
          # from
          class Error < StandardError; end

          # @param cluster [#to_s] the cluster name
          # @param bin [#to_s] path to LSF installation binaries
          def initialize(bin: "")
            # TODO: @cluster = cluster.to_s
            @bin     = Pathname.new(bin.to_s)
          end

          # Get a list of hashes detailing each of the jobs on the batch server
          # @param id [#to_s] the id of the job to check (if just checking one job)
          # @param filters [Array<Symbol>] list of attributes to filter on
          # @raise [Error] if `bjobs` command exited unsuccessfully
          # @return [Array<Hash>] list of details for jobs
          def get_jobs(id: "", filters: [])
            #TODO: does filters make sense here?
            #TODO: split into get_all_jobs, get_my_jobs, get_job?
            parse_bjobs_output call("bjobs -u all -a -w -W", id.to_s)
          end

          # helper method
          def parse_bjobs_output(response)
            raise NotImplementedError
          end

          # Put a specified job on hold
          # @example Put job "1234" on hold
          #   my_batch.hold_job("1234")
          # @param id [#to_s] the id of the job
          # @raise [Error] if `bstop` command exited unsuccessfully
          # @return [void]
          def hold_job(id)
            call("bstop", id.to_s)
          end

          # Release a specified job that is on hold
          # @example Release job "1234" from on hold
          #   my_batch.release_job("1234")
          # @param id [#to_s] the id of the job
          # @raise [Error] if `bresume` command exited unsuccessfully
          # @return [void]
          def release_job(id)
            call("bresume", id.to_s)
          end

          # Delete a specified job from batch server
          # @example Delete job "1234"
          #   my_batch.delete_job("1234")
          # @param id [#to_s] the id of the job
          # @raise [Error] if `bkill` command exited unsuccessfully
          # @return [void]
          def delete_job(id)
            call("bkill", id.to_s)
          end

          # Submit a script expanded as a string to the batch server
          # @param str [#to_s] script as a string
          # @param args [Array<#to_s>] arguments passed to `sbatch` command
          # @param env [Hash{#to_s => #to_s}] environment variables set
          # @raise [Error] if `bsub` command exited unsuccessfully
          # @return [String] the id of the job that was created
          def submit_string(str, args: [], env: {})
            args = args.map(&:to_s)
            parse_sbatch_response call("bsub", *args, env: env, stdin: str.to_s)
          end

          # helper method
          def parse_bsub_output(response)
            raise NotImplementedError
          end

          private
            # Call a forked Lsf command for a given cluster
            def call(cmd, *args, env: {}, stdin: "")
              cmd = bin.join(cmd.to_s).to_s
              #TODO: args = ["-m", cluster] + args.map(&:to_s)
              env = env.to_h
              o, e, s = Open3.capture3(env, cmd, *(args.map(&:to_s)), stdin_data: stdin.to_s)
              s.success? ? o : raise(Error, e)
            end
        end


        STATE_MAP = {
           #TODO: map LSF states to queued, queued_held, running, etc.
        }

        # @param opts [#to_h] the options defining this adapter
        # @option config [#to_s] :host The batch server host
        # @option config [#to_s] :lib ('') Path to lsf client libraries
        # @option config [#to_s] :bin ('') Path to lsf client binaries
        def initialize(config)
          @lib = Pathname.new(config.fetch(:lib, "").to_s)
          @bin = Pathname.new(config.fetch(:bin, "").to_s)
        end

        # Submit a job with the attributes defined in the job template instance
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
        # @raise [JobAdapterError] if something goes wrong submitting a job
        # @return [String] the job id returned after successfully submitting a job
        # @see Adapter#submit
        def submit(script:, after: [], afterok: [], afternotok: [], afterany: [])
          # ensure dependencies are array of ids
          after      = Array(after).map(&:to_s)
          afterok    = Array(afterok).map(&:to_s)
          afternotok = Array(afternotok).map(&:to_s)
          afterany   = Array(afterany).map(&:to_s)

          #TODO: see example in torque.rb for separating options as:
          # headers, dependencies, resources, environment vars, native args

          params = []
          #TODO:
          #-clusters ?

          env = {
            #TODO:
            #LSB_HOSTS?
            #LSB_MCPU_HOSTS?
            #SNDJOBS_TO?
            #
          }

          cmd = bin.join("bsub").to_s
          o, e, s = Open3.capture3(env, cmd, *params, stdin_data: script.content)

          raise JobAdapterError, e unless s.success?
          o.strip
        end

        # Retrieve job info from the resource manager
        # @abstract Subclass is expected to implement {#info}
        # @raise [NotImplementedError] if subclass did not define {#info}
        # @param id [#to_s] the id of the job, otherwise get list of all jobs
        #   running on cluster
        # @return [Info, Array<Info>] information describing submitted job
        def info(id: '')
          id = id.to_s

          raise NotImplementedError, "subclass did not define #info"
        end

        # Retrieve job status from resource manager
        # @note Optimized slightly over retrieving complete job information from server
        # @abstract Subclass is expected to implement {#status}
        # @raise [NotImplementedError] if subclass did not define {#status}
        # @param id [#to_s] the id of the job
        # @return [Status] status of job
        def status(id:)
          id = id.to_s

          raise NotImplementedError, "subclass did not define #status"
        end

        # Put the submitted job on hold
        # @abstract Subclass is expected to implement {#hold}
        # @raise [NotImplementedError] if subclass did not define {#hold}
        # @param id [#to_s] the id of the job
        # @return [void]
        def hold(id:)
          id = id.to_s

          raise NotImplementedError, "subclass did not define #hold"
        end

        # Release the job that is on hold
        # @abstract Subclass is expected to implement {#release}
        # @raise [NotImplementedError] if subclass did not define {#release}
        # @param id [#to_s] the id of the job
        # @return [void]
        def release(id:)
          id = id.to_s

          raise NotImplementedError, "subclass did not define #release"
        end

        # Delete the submitted job
        # @abstract Subclass is expected to implement {#delete}
        # @raise [NotImplementedError] if subclass did not define {#delete}
        # @param id [#to_s] the id of the job
        # @return [void]
        def delete(id:)
          id = id.to_s

          raise NotImplementedError, "subclass did not define #delete"
        end
      end
    end
  end
end
