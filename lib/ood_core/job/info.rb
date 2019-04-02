require 'time'

module OodCore
  module Job
    # An object that describes a submitted job
    class Info
      # The identifier of the job
      # @return [String] job id
      attr_reader :id

      # The status of the job
      # @return [Status] job state
      attr_reader :status

      # Set of machines that is utilized for job execution
      # @return [Array<NodeInfo>] allocated nodes
      attr_reader :allocated_nodes

      # Name of the submission host for this job
      # @return [String, nil] submit host
      attr_reader :submit_host

      # Name of the job
      # @return [String, nil] job name
      attr_reader :job_name

      # Owner of job
      # @return [String, nil] job owner
      attr_reader :job_owner

      # The account the job is charged against
      # @return [String, nil] accounting id
      attr_reader :accounting_id

      # Number of procs allocated for job
      # @return [Integer, nil] allocated total number of procs
      attr_reader :procs

      # Name of the queue in which the job was queued or started
      # @return [String, nil] queue name
      attr_reader :queue_name

      # The accumulated wall clock time in seconds
      # @return [Integer, nil] wallclock time
      attr_reader :wallclock_time

      # The total wall clock time limit in seconds
      # @return [Integer, nil] wallclock time limit
      attr_reader :wallclock_limit

      # The accumulated CPU time in seconds
      # @return [Integer, nil] cpu time
      attr_reader :cpu_time

      # The time at which the job was submitted
      # @return [Time, nil] submission time
      attr_reader :submission_time

      # The time the job first entered a "Started" state
      # @return [Time, nil] dispatch time
      attr_reader :dispatch_time

      # Native resource manager output for job info
      # @note Should not be used by generic apps
      # @return [Object] native info
      attr_reader :native

      # List of job array child task statuses
      # @note only relevant for job arrays
      # @return [Array<Task>] tasks
      attr_reader :tasks

      # @param id [#to_s] job id
      # @param status [#to_sym] job state
      # @param allocated_nodes [Array<#to_h>] allocated nodes
      # @param submit_host [#to_s, nil] submit host
      # @param job_name [#to_s, nil] job name
      # @param job_owner [#to_s, nil] job owner
      # @param accounting_id [#to_s, nil] accounting id
      # @param procs [#to_i, nil] allocated total number of procs
      # @param queue_name [#to_s, nil] queue name
      # @param wallclock_time [#to_i, nil] wallclock time
      # @param wallclock_limit [#to_i, nil] wallclock time limit
      # @param cpu_time [#to_i, nil] cpu time
      # @param submission_time [#to_i, nil] submission time
      # @param dispatch_time [#to_i, nil] dispatch time
      # @param tasks [Array<Hash>] tasks e.g. { id: '12345.owens-batch', status: :running }
      # @param native [Object] native info
      def initialize(id:, status:, allocated_nodes: [], submit_host: nil,
                     job_name: nil, job_owner: nil, accounting_id: nil,
                     procs: nil, queue_name: nil, wallclock_time: nil,
                     wallclock_limit: nil, cpu_time: nil, submission_time: nil,
                     dispatch_time: nil, native: nil, tasks: [],
                     **_)
        @id              = id.to_s
        @status          = Status.new(state: status.to_sym)
        @allocated_nodes = allocated_nodes.map { |n| NodeInfo.new(n.to_h) }
        @submit_host     = submit_host     && submit_host.to_s
        @job_name        = job_name        && job_name.to_s
        @job_owner       = job_owner       && job_owner.to_s
        @accounting_id   = accounting_id   && accounting_id.to_s
        @procs           = procs           && procs.to_i
        @queue_name      = queue_name      && queue_name.to_s
        @wallclock_time  = wallclock_time  && wallclock_time.to_i
        @wallclock_limit = wallclock_limit && wallclock_limit.to_i
        @cpu_time        = cpu_time        && cpu_time.to_i
        @submission_time = submission_time && Time.at(submission_time.to_i)
        @dispatch_time   = dispatch_time   && Time.at(dispatch_time.to_i)
        @tasks = tasks.map {|task_status| Task.new(**task_status)}

        @status = job_array_aggregate_status unless @tasks.empty?

        @native          = native
      end

      # Create a new Info for a child task
      # @return [Info] merging the parent and the child task
      def build_child_info(task)
        parent_only_keys = [
          :allocated_nodes,
          :procs,
          :cpu_time,
          :dispatch_time,
          :native,
          :tasks
        ]

        new(**to_h.merge(task.to_h).delete_if{|k, v| parent_only_keys.include?(k)})
      end

      # Convert object to hash
      # @return [Hash] object as hash
      def to_h
        {
          id:              id,
          status:          status,
          allocated_nodes: allocated_nodes,
          submit_host:     submit_host,
          job_name:        job_name,
          job_owner:       job_owner,
          accounting_id:   accounting_id,
          procs:           procs,
          queue_name:      queue_name,
          wallclock_time:  wallclock_time,
          wallclock_limit: wallclock_limit,
          cpu_time:        cpu_time,
          submission_time: submission_time,
          dispatch_time:   dispatch_time,
          native:          native,
          tasks: tasks
        }
      end

      # The comparison operator
      # @param other [#to_h] object to compare against
      # @return [Boolean] whether objects are equivalent
      def ==(other)
        to_h == other.to_h
      end

      # Whether objects are identical to each other
      # @param other [#to_h] object to compare against
      # @return [Boolean] whether objects are identical
      def eql?(other)
        self.class == other.class && self == other
      end

      # Generate a hash value for this object
      # @return [Integer] hash value of object
      def hash
        [self.class, to_h].hash
      end

      private

      # Generate an aggregate status from child tasks
      # @return [OodCore::Job::Status]
      def job_array_aggregate_status
        @tasks.map { |task_status| task_status.status }.max
      end
    end
  end
end
