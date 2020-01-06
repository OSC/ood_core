class OodCore::Job::Adapters::Sge::Helper
  require 'ood_core/job/adapters/sge'

  using OodCore::Refinements::ArrayExtensions

  # Convert seconds to duration
  # @param time [#to_i]
  # @return [String] an SGE qsub compatible wallclock limit
  def seconds_to_duration(time)
    time = time.to_i
    "%02d:%02d:%02d" % [time/3600, time/60%60, time%60]
  end

  # Convert script and job dependencies to qsub argument vector
  # @return args [Array<String>]
  def batch_submit_args(script, sanitize_job_name, after: [], afterok: [], afternotok: [], afterany: [])
    raise_error_on_unsupported_args(script, after: after, afterok: afterok, afternotok: afternotok, afterany: afterany)

    args = []
    args += ['-h'] if script.submit_as_hold
    args += ['-r', 'yes'] if script.rerunnable
    script.job_environment.each_pair {|k, v| args += ['-v', "#{k.to_s}=#{v.to_s}"]} unless script.job_environment.nil?
    args += ["-V"] if script.copy_environment?

    if script.workdir
      args += ['-wd', script.workdir]
    elsif ! script_contains_wd_directive?(script.content)
      args += ['-cwd']
    end

    on_event_email = []
    on_event_email << 'b' if script.email_on_started  # beginning
    on_event_email << 'ea' if script.email_on_terminated  # end, aborted

    args += ['-M', script.email.first, '-m', on_event_email.join] if script.email && ! on_event_email.empty?

    afterok  = Array(afterok).map(&:to_s)
    args += ['-hold_jid_ad', afterok.join(',')] unless afterok.empty?

    # ignoring email_on_started
    args += ['-N', job_name(script.job_name, sanitize_job_name)] unless script.job_name.nil?
    args += ['-e', script.error_path] unless script.error_path.nil?
    args += ['-o', script.output_path] unless script.output_path.nil?
    args += ['-ar', script.reservation_id] unless script.reservation_id.nil?
    args += ['-q', script.queue_name] unless script.queue_name.nil?
    args += ['-p', script.priority] unless script.priority.nil?
    args += ['-a', script.start_time.strftime('%C%y%m%d%H%M.%S')] unless script.start_time.nil?
    args += ['-l', "h_rt=" + seconds_to_duration(script.wall_time)] unless script.wall_time.nil?
    args += ['-P', script.accounting_id] unless script.accounting_id.nil?
    args += ['-t', script.job_array_request] unless script.job_array_request.nil?
    args += Array.wrap(script.native) if script.native

    args
  end

  # @brief      Detect whether script content contains either -cwd or -wd
  #
  # @param      content  The script content
  #
  # Examples:
  #     #$-wd /home/ood/ondemand  # should match
  #     #$  -wd /home/ood/ondemand  # should match
  #     #$  -cwd /home/ood/ondemand  # should match
  #     #$ -j yes -wd /home/ood/ondemand  # should match
  #     #$ -j yes -o this-wd /home/ood/ondemand  # should NOT match
  #       #$ -t 1-10:5 -wd /home/ood/ondemand  # should NOT match
  #
  # @return     [bool]
  #
  def script_contains_wd_directive?(content)
    content.slice(
      # Only search within the script's first 1024 characters in case the user is
      # putting lots of non-line delimited data into their scripts.
      0, 1024
    ).split(
      "\n"
    ).any? {
      |line|
      # String must start with #$
      # Match may be:
      #   Immediate -c?wd
      #   Eventual space or tab followed by -c?wd
      # String may end with multiple characters
      /^#\$(?:-c?wd|.*[ \t]+-c?wd).*$/ =~ line
    }
  end

  # Raise exceptions when adapter is asked to perform an action that SGE does not support
  # @raise [Error] when an incompatible action is requested
  def raise_error_on_unsupported_args(script, after:, afterok:, afternotok:, afterany:)
    # SGE job dependencies only supports one kind of event: completion
    raise OodCore::Job::Adapters::Sge::Error.new('SGE does not support job dependencies on after start') if after && ! after.empty?
    raise OodCore::Job::Adapters::Sge::Error.new('SGE does not support job dependencies on after not ok') if afternotok && ! afternotok.empty?
    raise OodCore::Job::Adapters::Sge::Error.new('SGE does not support job dependencies on after any') if afterany && ! afterany.empty?
  end

  # Sanitize a job name replacing illegal characters with underscores
  # @param     job_name     The job name to sanitize
  # @param     sanitize_job_name Boolean flag
  # @return    job_name     The possibly sanitized job name
  #
  # Grid Engine circa 2007 said this about the spec for their job names:
  #
  #     name
  #       The name may be any arbitrary alphanumeric ASCII string, but
  #       may  not contain  "\n", "\t", "\r", "/", ":", "@", "\", "*",
  #       or "?".
  def job_name(job_name, sanitize_job_name=false)
    return job_name unless sanitize_job_name

    # sftp://user@host.edu/place:22 -> sftp___user_host.edu_place_22
    # where the regex is in the form [blacklist]|[negation of whitelist]
    job_name.gsub(/([\s\n\t\r\/:@\\*]|[^\x00-\x7F])/, '_')
  end

  # Extract the job id from qsub's output
  # e.g. Your job 1043 ("job_16") has been submitted
  # @param qsub_output [#to_s]
  # @return job_id [String]
  def parse_job_id_from_qsub(qsub_output)
    /Your job(?:-array)? (?<job_id>[0-9]+)/.match(qsub_output)[:job_id]
  end
end