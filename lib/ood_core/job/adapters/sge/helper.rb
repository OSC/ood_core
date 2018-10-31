class OodCore::Job::Adapters::Sge::Helper
  require 'ood_core/job/adapters/sge'

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
    args += ['-h'] if script.submit_as_hold
    args += ['-r', 'yes'] if script.rerunnable
    script.job_environment.each_pair {|k, v| args += ['-v', "#{k.to_s}=#{v.to_s}"]} unless script.job_environment.nil?
    args += ['-wd', script.workdir] unless script.workdir.nil?

    on_event_email = []
    on_event_email << 'b' if script.email_on_started  # beginning
    on_event_email << 'ea' if script.email_on_terminated  # end, aborted

    args += ['-M', script.email.first, '-m', on_event_email.join] if script.email && ! on_event_email.empty?

    afterok  = Array(afterok).map(&:to_s)
    args += ['-hold_jid_ad', afterok.join(',')] unless afterok.empty?

    # ignoring email_on_started
    args += ['-N', script.job_name] unless script.job_name.nil?
    args += ['-e', script.error_path] unless script.error_path.nil?
    args += ['-o', script.output_path] unless script.output_path.nil?
    args += ['-ar', script.reservation_id] unless script.reservation_id.nil?
    args += ['-q', script.queue_name] unless script.queue_name.nil?
    args += ['-p', script.priority] unless script.priority.nil?
    args += ['-a', script.start_time.strftime('%C%y%m%d%H%M.%S')] unless script.start_time.nil?
    args += ['-l', "h_rt=" + seconds_to_duration(script.wall_time)] unless script.wall_time.nil?
    args += ['-P', script.accounting_id] unless script.accounting_id.nil?
    args += Array.wrap(script.native) if script.native

    args
  end

  # Raise exceptions when adapter is asked to perform an action that SGE does not support
  # @raise [Error] when an incompatible action is requested
  def raise_error_on_unsupported_args(script, after:, afterok:, afternotok:, afterany:)
    # SGE job dependencies only supports one kind of event: completion
    raise OodCore::Job::Adapters::Sge::Error.new('SGE does not support job dependencies on after start') if after && ! after.empty?
    raise OodCore::Job::Adapters::Sge::Error.new('SGE does not support job dependencies on after not ok') if afternotok && ! afternotok.empty?
    raise OodCore::Job::Adapters::Sge::Error.new('SGE does not support job dependencies on after any') if afterany && ! afterany.empty?
  end

  # Convert qacct output into key, value pairs
  # @param output [#to_s]
  # @return [Hash<Symbol, String>]
  def parse_qacct_output(output)
    result.split("\n").map do |str|
      key_value = /^(?<key>[a-z_]+) +(?<value>.+)/.match(str)
      next unless key_value
      key = key_value[:key].strip.gsub(' ', '_').to_sym
      value = key_value[:value].strip

      [key, value]
    end.compact.to_h
  end

  # Extract the job id from qsub's output
  # e.g. Your job 1043 ("job_16") has been submitted
  # @param qsub_output [#to_s]
  # @return job_id [String]
  def parse_job_id_from_qsub(qsub_output)
    /Your job (?<job_id>[0-9]+)/.match(qsub_output)[:job_id]
  end
end