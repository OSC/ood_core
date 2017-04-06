# Object used for simplified communication with a LSF batch server
#
# @note Used by Lsf adapter and not meant to be used directly.
# @private
class OodCore::Job::Adapters::Lsf::Batch
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
    id = id.to_s
    #TODO: does filters make sense here? regardless this is a speed enhancement
    # selected_fields = filters.empty? ? fields : (filters & fields)
    #TODO: split into get_all_jobs, get_my_jobs, get_job?
    args = bjobs_default_args

    #TODO: get_jobs with a list of ids...
    # get_jobs(ids = []) *(ids.map(&:to_s))
    args << id unless id.empty?

    parse_bjobs_output call("bjobs", *args)
  end

  def bjobs_default_args
    %w( -u all -a -w -W )
  end

  # helper method
  def parse_bjobs_output(response)
    return [{}] if response =~ /No job found/ || response.nil?

    lines = response.split("\n")
    validate_bjobs_output_columns(lines.first.split)

    lines.drop(1).map{ |job|
      values = split_bjobs_output_line(job)

      # make a hash of { field: "value", etc. }
      Hash[fields.zip(values)].each_with_object({}) { |(k,v),o|
        # if the value == "-", replace it with nil
        o[k] = (v == "-" ? nil : v)
      }
    }
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
    parse_bsub_output call("bsub", *args, env: env, stdin: str.to_s)
  end

  # helper method
  def parse_bsub_output(response)
    if response =~ /Job <(.*)> /
      $1
    else
      nil
    end
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

    # split a line of output from bjobs into field values
    def split_bjobs_output_line(line)
      values = line.strip.split

      if(values.count > 15)
        # FIXME: hack assumes 15 fields & only job name may have spaces
        # collapse >15 fields into 15, assumes 7th field is JOB_NAME
        values = values[0..5] + [values[6..-9].join(" ")] + values[-8..-1]
      end

      values
    end

    # verify the output from bjobs is parsable by this object
    def validate_bjobs_output_columns(columns)
      expected = %w(JOBID USER STAT QUEUE FROM_HOST EXEC_HOST JOB_NAME
                    SUBMIT_TIME PROJ_NAME CPU_USED MEM SWAP PIDS START_TIME FINISH_TIME)
      if columns != expected
        raise Error, "bjobs output in different format than expected: " \
          "#{columns.inspect} instead of #{expected.inspect}"
      end
    end

    # status fields available from bjobs
    def fields
      %i(id user status queue from_host exec_host name submit_time
          project cpu_used mem swap pids start_time finish_time)
    end
end
