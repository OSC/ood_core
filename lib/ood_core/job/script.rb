require 'pathname'
require 'time'
require 'ood_core/refinements/array_extensions'

module OodCore
  module Job
    # An object that describes a batch job before it is submitted. This includes
    # the resources this batch job will require of the resource manager.
    class Script
      using Refinements::ArrayExtensions

      # Content of the script to be executed on the remote host
      # @return [String] the script content
      attr_reader :content

      # Arguments supplied to script to be executed
      # @return [Array<String>, nil] arguments supplied to script
      attr_reader :args

      # Whether job is held after submitted
      # @return [Boolean, nil] whether job is held after submit
      attr_reader :submit_as_hold

      # Whether job can safely be restarted by the resource manager, for example on
      # node failure or some other re-scheduling event
      # @note This SHOULD NOT be used to let the application denote the
      #   checkpointability of a job
      # @return [Boolean, nil] whether job can be restarted
      attr_reader :rerunnable

      # Environment variables to be set on remote host when running job
      # @note These will override the remote host environment settings
      # @return [Hash{String=>String}, nil] environment variables
      attr_reader :job_environment

      # Directory where the job is executed from
      # @return [Pathname, nil] working directory
      attr_reader :workdir

      # List of email addresses that should be used when resource manager sends
      # status notifications
      # @return [Array<String>, nil] list of emails
      attr_reader :email

      # Whether given email addresses should be notified when job starts
      # @return [Boolean, nil] whether email when job starts
      attr_reader :email_on_started

      # Whether given email addresses should be notified when job ends
      # @return [Boolean, nil] whether email when job ends
      attr_reader :email_on_terminated

      # The name of the job
      # @return [String, nil] name of job
      attr_reader :job_name

      # Path to file specifying the login shell of the job
      # @return [Pathname, nil] file path specifying login shell
      attr_reader :shell_path

      # Path to file specifying the input stream of the job
      # @return [Pathname, nil] file path specifying input stream
      attr_reader :input_path

      # Path to file specifying the output stream of the job
      # @return [Pathname, nil] file path specifying output stream
      attr_reader :output_path

      # Path to file specifying the error stream of the job
      # @return [Pathname, nil] file path specifying error stream
      attr_reader :error_path

      # Identifier of existing reservation to be associated with the job
      # @return [String, nil] reservation id
      attr_reader :reservation_id

      # Name of the queue the job should be submitted to
      # @return [String, nil] queue name
      attr_reader :queue_name

      # The scheduling priority for the job
      # @return [Integer, nil] scheduling priority
      attr_reader :priority

      # The earliest time when the job may be eligible to run
      # @return [Time, nil] eligible start time
      attr_reader :start_time

      # The maximum amount of real time during which the job can be running in
      # seconds
      # @return [Integer, nil] max real time
      attr_reader :wall_time

      # The attribute used for job accounting purposes
      # @return [String, nil] accounting id
      attr_reader :accounting_id

      # The job array request, commonly in the format '$START-$STOP'
      # @return [String, nil] job array request
      attr_reader :job_array_request

      # The qos selected for the job
      # @return [String, nil] qos
      attr_reader :qos

      # The GPUs per node for the job
      # @return [Integer, nil] gpus per node
      attr_reader :gpus_per_node

      # Object detailing any native specifications that are implementation specific
      # @note Should not be used at all costs.
      # @return [Object, nil] native specifications
      attr_reader :native

      # Flag whether the job should contain a copy of its calling environment
      # @return [Boolean] copy environment
      attr_reader :copy_environment
      alias_method :copy_environment?, :copy_environment

      # @param content [#to_s] the script content
      # @param args [Array<#to_s>, nil] arguments supplied to script
      # @param submit_as_hold [Boolean, nil] whether job is held after submit
      # @param rerunnable [Boolean, nil] whether job can be restarted
      # @param job_environment [Hash{#to_s => #to_s}, nil] environment variables
      # @param workdir [#to_s, nil] working directory
      # @param email [#to_s, Array<#to_s>, nil] list of emails
      # @param email_on_started [Boolean, nil] whether email when job starts
      # @param email_on_terminated [Boolean, nil] whether email when job ends
      # @param job_name [#to_s, nil] name of job
      # @param shell_path [#to_s, nil] file path specifying login shell
      # @param error_path [#to_s, nil] file path specifying error stream
      # @param input_path [#to_s, nil] file path specifying input stream
      # @param output_path [#to_s, nil] file path specifying output stream
      # @param error_path [#to_s, nil] file path specifying error stream
      # @param reservation_id [#to_s, nil] reservation id
      # @param queue_name [#to_s, nil] queue name
      # @param priority [#to_i, nil] scheduling priority
      # @param start_time [#to_i, nil] eligible start time
      # @param wall_time [#to_i, nil] max real time
      # @param accounting_id [#to_s, nil] accounting id
      # @param job_array_request [#to_s, nil] job array request
      # @param qos [#to_s, nil] qos
      # @param gpus_per_node [#to_i, nil] gpus per node
      # @param native [Object, nil] native specifications
      # @param copy_environment [Boolean, nil] copy the environment
      def initialize(content:, args: nil, submit_as_hold: nil, rerunnable: nil,
                     job_environment: nil, workdir: nil, email: nil,
                     email_on_started: nil, email_on_terminated: nil,
                     job_name: nil, shell_path: nil, input_path: nil,
                     output_path: nil, error_path: nil, reservation_id: nil,
                     queue_name: nil, priority: nil, start_time: nil,
                     wall_time: nil, accounting_id: nil, job_array_request: nil,
                     qos: nil, gpus_per_node: nil, native: nil, copy_environment: nil, **_)
        @content = content.to_s

        @submit_as_hold      = submit_as_hold
        @rerunnable          = rerunnable
        @email_on_started    = email_on_started
        @email_on_terminated = email_on_terminated

        @args               = args              && args.map(&:to_s)
        @job_environment    = job_environment   && job_environment.each_with_object({}) { |(k, v), h| h[k.to_s] = v.to_s }
        @workdir            = workdir           && Pathname.new(workdir.to_s)
        @email              = email             && Array.wrap(email).map(&:to_s)
        @job_name           = job_name          && job_name.to_s
        @shell_path         = shell_path        && Pathname.new(shell_path.to_s)
        @input_path         = input_path        && Pathname.new(input_path.to_s)
        @output_path        = output_path       && Pathname.new(output_path.to_s)
        @error_path         = error_path        && Pathname.new(error_path.to_s)
        @reservation_id     = reservation_id    && reservation_id.to_s
        @queue_name         = queue_name        && queue_name.to_s
        @priority           = priority          && priority.to_i
        @start_time         = start_time        && Time.at(start_time.to_i)
        @wall_time          = wall_time         && wall_time.to_i
        @accounting_id      = accounting_id     && accounting_id.to_s
        @job_array_request  = job_array_request && job_array_request.to_s
        @qos                = qos               && qos.to_s
        @gpus_per_node      = gpus_per_node     && gpus_per_node.to_i
        @native             = native
        @copy_environment   = (copy_environment.nil?) ? nil : !! copy_environment
      end

      # Convert object to hash
      # @return [Hash] object as hash
      def to_h
        {
          content:             content,
          args:                args,
          submit_as_hold:      submit_as_hold,
          rerunnable:          rerunnable,
          job_environment:     job_environment,
          workdir:             workdir,
          email:               email,
          email_on_started:    email_on_started,
          email_on_terminated: email_on_terminated,
          job_name:            job_name,
          shell_path:          shell_path,
          input_path:          input_path,
          output_path:         output_path,
          error_path:          error_path,
          reservation_id:      reservation_id,
          queue_name:          queue_name,
          priority:            priority,
          start_time:          start_time,
          wall_time:           wall_time,
          accounting_id:       accounting_id,
          job_array_request:   job_array_request,
          qos:                 qos,
          gpus_per_node:       gpus_per_node,
          native:              native,
          copy_environment:    copy_environment
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
    end
  end
end
