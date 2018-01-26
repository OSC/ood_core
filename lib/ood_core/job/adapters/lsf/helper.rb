# Object used for simplified communication with a LSF batch server
#
# @api private
class OodCore::Job::Adapters::Lsf::Helper

  # convert string in format "03/31-14:46:42" to Time object
  # assumes time being parsed is a time that ocurred in the past
  # not to be used for parsing times in the future (like estimated FINISH_TIME)
  def parse_past_time(t, ignore_errors: false)
    return nil if t.nil? || t.empty? || t == "-"
    year = Time.now.year
    time = Time.parse("#{year}/#{t}")

    # handle edge case where job started before new year
    time = Time.parse("#{year - 1}/#{t}") if time.month > Time.now.month

    time

  rescue ArgumentError => e
    raise e unless ignore_errors

    #TODO: warn via logger

    nil
  end

  # convert exec_host string format from bjobs to a hash
  # i.e. "c012" => [{host: "c012", slots: 1}]
  # i.e. "4*c012:8*c013" => [{host: "c012", slots: 4}, {host: "c013", slots: 8}]
  # i.e. "c012:c012" => [{host: "c012", slots: 2}]
  def parse_exec_host(exec_host_str)
    return [] if exec_host_str.nil? || exec_host_str.empty?

    exec_host_str.scan(exec_host_regex).map do |match|
      {host: match[2], slots: match[1] ? match[1].to_i : 1}
    end.group_by { |node| node[:host] }.map do |host, nodes|
      slots = nodes.reduce(0) { |count, node| count + node[:slots] }
      {host: host, slots: slots}
    end
  end

  def exec_host_regex
    @exec_host_regex ||= Regexp.new(/((\d+)\*)?([^:]+)/)
  end

  # given current time, dispatch time, and finish time values, estimate the
  # runtime for a job; this estimate will be accurate if the job never enters a
  # suspended state during its execution
  def estimate_runtime(current_time:, start_time:, finish_time:)
    return nil if start_time.nil?

    (finish_time || current_time) - start_time
  end

  # Convert CPU_USED string to seconds
  #
  # example strings of cpu_used in LSF 8.3:
  #
  # 060:24:00.00
  # 046:19:37.00
  # 1118:59:09.00
  # 000:00:00.00
  # 000:48:18.39
  # 003:11:36.67
  # 003:24:40.95
  # 50769:48:00.-48
  # 50835:48:48.-48
  #
  # my guess is: hours:minutes:seconds.????
  #
  # @return [Fixnum, nil] cpu used as seconds
  def parse_cpu_used(cpu_used)
    if cpu_used =~ /^(\d+):(\d+):(\d+)\..*$/
      $1.to_i*3600 + $2.to_i*60 + $3.to_i
    end
  end

  def batch_submit_args(script, after: [], afterok: [], afternotok: [], afterany: [])
    args = []

    args += ["-P", script.accounting_id] unless script.accounting_id.nil?
    args += ["-cwd", script.workdir.to_s] unless script.workdir.nil?
    args += ["-J", script.job_name] unless script.job_name.nil?
    args += ["-q", script.queue_name] unless script.queue_name.nil?
    args += ["-U", script.reservation_id] unless script.reservation_id.nil?
    args += ["-sp", script.priority] unless script.priority.nil?
    args += ["-H"] if script.submit_as_hold
    args += (script.rerunnable ? ["-r"] : ["-rn"]) unless script.rerunnable.nil?
    args += ["-b", script.start_time.localtime.strftime("%Y:%m:%d:%H:%M")] unless script.start_time.nil?
    args += ["-W", (script.wall_time / 60).to_i] unless script.wall_time.nil?

    # input and output files
    args += ["-i", script.input_path] unless script.input_path.nil?
    args += ["-o", script.output_path] unless script.output_path.nil?
    args += ["-e", script.error_path] unless script.error_path.nil?

    # email
    args += ["-B"] if script.email_on_started
    args += ["-N"] if script.email_on_terminated
    args += ["-u", script.email.join(",")] unless script.email.nil? || script.email.empty?

    args += script.native unless script.native.nil?

    # environment
    env = script.job_environment || {}

    {args: args, env: env}
  end
end
