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
      # @return [String] submit host
      attr_reader :submit_host

      # Name of the job
      # @return [String] job name
      attr_reader :job_name

      # Owner of job
      # @return [String] job owner
      attr_reader :job_owner

      # The account the job is charged against
      # @return [String] accounting id
      attr_reader :accounting_id

      # Number of procs allocated for job
      # @return [Fixnum] allocated total number of procs
      attr_reader :procs

      # Name of the queue in which the job was queued or started
      # @return [String] queue name
      attr_reader :queue_name

      # The accumulated wall clock time in seconds
      # @return [Fixnum] wallclock time
      attr_reader :wallclock_time

      # The accumulated CPU time in seconds
      # @return [Fixnum] cpu time
      attr_reader :cpu_time

      # The time at which the job was submitted
      # @return [Time] submission time
      attr_reader :submission_time

      # The time the job first entered a "Started" state
      # @return [Time] dispatch time
      attr_reader :dispatch_time

      # Native resource manager output for job info
      # @note Should not be used by generic apps
      # @return [Object] native info
      attr_reader :native

      # @param id [#to_s] job id
      # @param status [#to_sym] job state
      # @param allocated_nodes [Array<#to_h>] allocated nodes
      # @param submit_host [#to_s] submit host
      # @param job_name [#to_s] job name
      # @param job_owner [#to_s] job owner
      # @param accounting_id [#to_s] accounting id
      # @param procs [#to_i] allocated total number of procs
      # @param queue_name [#to_s] queue name
      # @param wallclock_time [#to_i] wallclock time
      # @param cpu_time [#to_i] cpu time
      # @param submission_time [#to_i] submission time
      # @param dispatch_time [#to_i] dispatch time
      # @param native [Object] native info
      def initialize(id:, status:, allocated_nodes: [], submit_host: '',
                     job_name: '', job_owner: '', accounting_id: '', procs: 0,
                     queue_name: '', wallclock_time: 0, cpu_time: 0,
                     submission_time: 0, dispatch_time: 0, native: nil, **_)
        @id              = id.to_s
        @status          = Status.new(state: status.to_sym)
        @allocated_nodes = allocated_nodes.map { |n| NodeInfo.new(n.to_h) }
        @submit_host     = submit_host.to_s
        @job_name        = job_name.to_s
        @job_owner       = job_owner.to_s
        @accounting_id   = accounting_id.to_s
        @procs           = procs.to_i
        @queue_name      = queue_name.to_s
        @wallclock_time  = wallclock_time.to_i
        @cpu_time        = cpu_time.to_i
        @submission_time = Time.at(submission_time.to_i)
        @dispatch_time   = Time.at(dispatch_time.to_i)
        @native          = native
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
          cpu_time:        cpu_time,
          submission_time: submission_time,
          dispatch_time:   dispatch_time,
          native:          native
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
      # @return [Fixnum] hash value of object
      def hash
        [self.class, to_h].hash
      end
    end
  end
end
