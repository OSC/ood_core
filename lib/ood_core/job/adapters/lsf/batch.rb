# Object used for simplified communication with a LSF batch server
#
# @api private
class OodCore::Job::Adapters::Lsf::Batch
  attr_reader :bindir, :libdir, :envdir, :serverdir, :cluster, :bin_overrides, :submit_host, :strict_host_checking

  # The root exception class that all LSF-specific exceptions inherit
  # from
  class Error < StandardError; end

  # @param bin [#to_s] path to LSF installation binaries
  def initialize(bindir: "", envdir: "", libdir: "", serverdir: "", cluster: "", bin_overrides: {}, submit_host: "", strict_host_checking: true, **_)
    @bindir = Pathname.new(bindir.to_s)
    @envdir = Pathname.new(envdir.to_s)
    @libdir = Pathname.new(libdir.to_s)
    @serverdir = Pathname.new(serverdir.to_s)
    @cluster = cluster.to_s
    @bin_overrides = bin_overrides
    @submit_host = submit_host.to_s
    @strict_host_checking = strict_host_checking
  end

  def default_env
    {
      "LSF_BINDIR" => bindir.to_s,
      "LSF_LIBDIR" => libdir.to_s,
      "LSF_ENVDIR" => envdir.to_s,
      "LSF_SERVERDIR" => serverdir.to_s
    }.reject {|k,v| v.nil? || v.empty? }
  end

  # Get a list of hashes detailing each of the jobs on the batch server
  # @raise [Error] if `bjobs` command exited unsuccessfully
  # @return [Array<Hash>] list of details for jobs
  def get_jobs
    get_jobs_for_user("all")
  end

  def get_jobs_for_user(user)
    args = %W( -u #{user} -a -w -W )
    parse_bjobs_output(call("bjobs", *args))
  end

  # Get hash detailing the specified job
  # @param id [#to_s] the id of the job to check
  # @raise [Error] if `bjobs` command exited unsuccessfully
  # @return [Array<Hash>] details of specified job
  def get_job(id:)
    args = %W( -a -w -W #{id.to_s} )
    parse_bjobs_output(call("bjobs", *args))
  end

  # status fields available from bjobs
  def fields
    %i(id user status queue from_host exec_host name submit_time
        project cpu_used mem swap pids start_time finish_time)
  end

  # helper method
  def parse_bjobs_output(response)
    return [] if response.nil? || response.strip.empty?

    lines = response.split("\n")
    raise Error, "bjobs output in different format than expected: #{lines.inspect}" unless lines.count > 1

    columns = lines.shift.split

    validate_bjobs_output_columns(columns)
    jobname_column_idx = columns.find_index("JOB_NAME")

    lines.map{ |job|
      values = split_bjobs_output_line(job, num_columns: columns.count, jobname_column_idx: jobname_column_idx)

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
    parse_bsub_output(call("bsub", *args, env: env, stdin: str.to_s))
  end

  # helper method
  def parse_bsub_output(response)
    if response =~ /Job <(.*)> /
      $1
    else
      nil
    end
  end

  def cluster_args
    if cluster.nil? || cluster.strip.empty?
      []
    else
      ["-m", cluster]
    end
  end

  private
    # Call a forked Lsf command for a given cluster
    def call(cmd, *args, env: {}, stdin: "")
      cmd = OodCore::Job::Adapters::Helper.bin_path(cmd, bindir, bin_overrides)
      args = cluster_args + args
      env = default_env.merge(env.to_h)
      cmd, args = OodCore::Job::Adapters::Helper.ssh_wrap(submit_host, cmd, args, strict_host_checking, env)
      o, e, s = Open3.capture3(env, cmd, *(args.map(&:to_s)), stdin_data: stdin.to_s)
      s.success? ? o : raise(Error, e)
    end

    # split a line of output from bjobs into field values
    def split_bjobs_output_line(line, num_columns:, jobname_column_idx:)
      values = line.strip.split

      if(values.count > num_columns)
        # if the line has more fields than the number of columns, that means one
        # field value has spaces, so it was erroneously split into
        # multiple fields; we assume that is the jobname field, and we will
        # collapse the fields into a single field
        #
        # FIXME: assumes jobname_column_idx is not first or last item
        j = jobname_column_idx

        # e.g. if 15 fields and jobname is 7th field
        # values = values[0..5] + [values[6..-9].join(" ")] + values[-8..-1]
        values = values[0..(j-1)] + [values[j..(j-num_columns)].join(" ")] + values[(j+1-num_columns)..-1]
      end

      values
    end

    # verify the output from bjobs is parsable by this object
    def validate_bjobs_output_columns(columns)
      expected = %w(JOBID USER STAT QUEUE FROM_HOST EXEC_HOST JOB_NAME
                    SUBMIT_TIME PROJ_NAME CPU_USED MEM SWAP PIDS START_TIME FINISH_TIME)
      # (expected & columns) will return the columns that are the same
      # so if there are extra columns we can just ignore those (like SLOTS in LSF 9.1)
      if columns && ((expected & columns) != expected)
        raise Error, "bjobs output in different format than expected: " \
          "#{columns.inspect} did not include all columns: #{expected.inspect}"
      end
    end

end
