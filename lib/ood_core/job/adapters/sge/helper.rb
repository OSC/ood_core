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
  def batch_submit_args(script, after: [], afterok: [], afternotok: [], afterany: [])
    raise_error_on_unsupported_args(script, after: after, afterok: afterok, afternotok: afternotok, afterany: afterany)

    args = []
    args.concat ['-h'] if script.submit_as_hold
    args.concat ['-r', 'yes'] if script.rerunnable
    script.job_environment.each_pair {|k, v| args.concat ['-v', "#{k.to_s}=#{v.to_s}"]} unless script.job_environment.nil?
    args.concat ["-V"] if script.copy_environment?

    if script.workdir
      args.concat ['-wd', script.workdir]
    elsif ! script_contains_wd_directive?(script.content)
      args.concat ['-cwd']
    end

    on_event_email = []
    on_event_email << 'b' if script.email_on_started  # beginning
    on_event_email << 'ea' if script.email_on_terminated  # end, aborted

    args.concat ['-M', script.email.first, '-m', on_event_email.join] if script.email && ! on_event_email.empty?

    afterok  = Array(afterok).map(&:to_s)
    args.concat ['-hold_jid_ad', afterok.join(',')] unless afterok.empty?

    # ignoring email_on_started
    args.concat ['-N', script.job_name] unless script.job_name.nil?
    args.concat ['-e', script.error_path] unless script.error_path.nil?
    args.concat ['-o', script.output_path] unless script.output_path.nil?
    args.concat ['-ar', script.reservation_id] unless script.reservation_id.nil?
    args.concat ['-q', script.queue_name] unless script.queue_name.nil?
    args.concat ['-p', script.priority] unless script.priority.nil?
    args.concat ['-a', script.start_time.strftime('%C%y%m%d%H%M.%S')] unless script.start_time.nil?
    args.concat ['-l', "h_rt=" + seconds_to_duration(script.wall_time)] unless script.wall_time.nil?
    args.concat ['-P', script.accounting_id] unless script.accounting_id.nil?
    args.concat ['-t', script.job_array_request] unless script.job_array_request.nil?
    args.concat Array.wrap(script.native) if script.native

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

  # Extract the job id from qsub's output
  # e.g. Your job 1043 ("job_16") has been submitted
  # @param qsub_output [#to_s]
  # @return job_id [String]
  def parse_job_id_from_qsub(qsub_output)
    /Your job(?:-array)? (?<job_id>[0-9]+)/.match(qsub_output)[:job_id]
  end
end