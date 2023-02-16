require 'erb'
require 'etc'
require 'pathname'
require 'securerandom'
require 'shellwords'
require 'time'

# Object used for simplified communication SSH hosts
#
# @api private
class OodCore::Job::Adapters::LinuxSystemd::Launcher
  attr_reader :debug, :site_timeout, :session_name_label, :ssh_hosts,
    :strict_host_checking, :username
  # The root exception class that all LinuxSystemd adapter-specific exceptions inherit
  # from
  class Error < StandardError; end

  # @param debug Whether the adapter should be used in debug mode
  # @param site_timeout [#to_i] A period after which the job should be killed or nil
  # @param ssh_hosts List of hosts to check when scanning for running jobs
  # @param strict_host_checking Allow SSH to perform strict host checking
  # @param submit_host The SSH-able host
  def initialize(
    debug: false,
    site_timeout: nil,
    ssh_hosts:,
    strict_host_checking: false,
    submit_host:,
    **_
  )
    @debug = !! debug
    @site_timeout = site_timeout.to_i
    @session_name_label = 'ondemand'
    @ssh_hosts = ssh_hosts
    @strict_host_checking = strict_host_checking
    @submit_host = submit_host
    @username = Etc.getlogin
  end

  # @param hostname [#to_s] The hostname to submit the work to
  # @param script [OodCore::Job::Script] The script object defining the work
  def start_remote_session(script)
    cmd = ssh_cmd(submit_host(script), ['/usr/bin/env', 'bash'])

    session_name = unique_session_name
    output = call(*cmd, stdin: wrapped_script(script, session_name))
    hostname = parse_hostname(output)

    "#{session_name}@#{hostname}"
  end

  def stop_remote_session(session_name, hostname)
    cmd = ssh_cmd(hostname, ['/usr/bin/env', 'bash'])

    kill_cmd = <<~SCRIPT
    # stop the session by name
    systemctl --user stop #{session_name}.service
    SCRIPT

    call(*cmd, stdin: kill_cmd)
  rescue Error => e
    interpret_and_raise(e)
  end

  def list_remote_sessions(host: nil)
    host_list = (host) ? [host] : ssh_hosts

    host_list.map {
      |hostname| list_remote_systemd_session(hostname)
    }.flatten.sort_by {
      |hsh| hsh[:session_name]
    }
  end

  def submit_host(script = nil)
    if script && script.native && script.native['submit_host_override']
      script.native['submit_host_override']
    else
      @submit_host
    end
  end

  private

  # Call a forked Slurm command for a given cluster
  def call(cmd, *args, env: {}, stdin: "")
    args  = args.map(&:to_s)
    env = env.to_h
    o, e, s = Open3.capture3(env, cmd, *args, stdin_data: stdin.to_s)
    s.success? ? o : raise(Error, e)
  end

  # The full command to ssh into the destination host and execute the command.
  # SSH options include:
  # -t Force pseudo-terminal allocation (required to allow tmux to run)
  # -o BatchMode=yes (set mode to be non-interactive)
  # if ! strict_host_checking
  # -o UserKnownHostsFile=/dev/null (do not update the user's known hosts file)
  # -o StrictHostKeyChecking=no (do no check the user's known hosts file)
  #
  # @param destination_host [#to_s] the destination host you wish to ssh into
  # @param cmd [Array<#to_s>] the command to be executed on the destination host
  def ssh_cmd(destination_host, cmd)
    if strict_host_checking
      [
        'ssh', '-t',
        '-p', ENV["OOD_SSH_PORT"].nil? "22" : "#{ENV['OOD_SSH_PORT']}",
        '-o', 'BatchMode=yes',
        "#{username}@#{destination_host}"
      ].concat(cmd)
    else
      [
        'ssh', '-t',
        '-p', ENV["OOD_SSH_PORT"].nil? ? "22" : "#{ENV['OOD_SSH_PORT']}",
        '-o', 'BatchMode=yes',
        '-o', 'UserKnownHostsFile=/dev/null',
        '-o', 'StrictHostKeyChecking=no',
        "#{username}@#{destination_host}"
      ].concat(cmd)
    end
  end

  def shell
    ENV['SHELL'] || '/bin/bash'
  end

  # Wraps a user-provided script into a systemd-run transient service
  def wrapped_script(script, session_name)
    content = script.content
    unless user_script_has_shebang?(script)
     content = "#!#{shell}\n#{content}"
    end

    ERB.new(
      File.read(Pathname.new(__dir__).join('templates/script_wrapper.erb.sh'))
    ).result(binding.tap {|bnd|
      {
        'arguments' => script_arguments(script),
        'cd_to_workdir' => (script.workdir) ? "cd #{script.workdir}" : '',
        'debug' => debug,
        'email_on_terminated' => script_email_on_event(script, 'terminated'),
        'email_on_start' => script_email_on_event(script, 'started'),
        'environment' => export_env(script),
        'error_path' => error_path(script),
        'job_name' => script.job_name.to_s,
        'output_path' => (script.output_path) ? script.output_path.to_s : '/dev/null',
        'script_content' => content,
        'script_timeout' => script_timeout(script),
        'session_name' => session_name,
        'ssh_hosts' => ssh_hosts,
        'workdir' => (script.workdir) ? script.workdir.to_s : '/tmp',
      }.each{
        |key, value| bnd.local_variable_set(key, value)
      }
    })
  end

  # Generate the environment export block for this script
  def export_env(script)
    environment = script.job_environment
    (environment ? environment : {}).map{
      |key, value| "export #{key}=#{Shellwords.escape(value)}"
    }.sort.join("\n")
  end

  def script_timeout(script)
    wall_time = script.wall_time.to_i
    if wall_time == 0
      # this is the only way it can be 0
      # so make it into infinify for systemd to never terminate
      site_timeout == 0 ? 'infinity' : site_timeout
    elsif site_timeout != 0
      [wall_time, site_timeout].min
    else
      wall_time
    end
  end

  def script_arguments(script)
    return '' unless script.args

    Shellwords.join(script.args)
  end

  def script_email_on_event(script, event)
    return false unless script.email && script.send("email_on_#{event}")

    ERB.new(
      File.read(Pathname.new(__dir__).join('templates/email.erb.sh'))
    ).result(binding.tap {|bnd|
      {
        'email_recipients' => script.email.map{|addr| Shellwords.escape(addr)}.join(', '),
        'job_name' => (script.job_name) ? script.job_name : 'LinuxHost_Adapter_Job',
        'job_status' => event
      }.each{
        |key, value| bnd.local_variable_set(key, value)
      }
    })
  end

  def unique_session_name
    "#{session_name_label}-#{SecureRandom.alphanumeric(10)}"
  end

  # List all Systemd sessions on destination_host started by this adapter
  def list_remote_systemd_session(destination_host)
    cmd = ssh_cmd(destination_host, ['systemctl', '--user', 'show', '-t', 'service', '--state=running', "#{session_name_label}-*"])

    # individual units are separated with an empty line
    call(*cmd).split("\n\n").map do |oneunit|
      Hash[oneunit.split("\n").map{ |line| line.split('=',2) }].tap do |session_hash|
         session_hash[:session_name] = session_hash['Id'].delete_suffix('.service')
         session_hash[:destination_host] = destination_host
         session_hash[:id] = "#{session_hash[:session_name]}@#{destination_host}"
         session_hash[:session_created] = Time.parse(session_hash['ExecMainStartTimestamp'])
	 session_hash[:job_name] = session_hash['Description']
      end
    end
  rescue Error => e
    interpret_and_raise(e)
    []
  end

  def user_script_has_shebang?(script)
    return false if script.content.empty?
    script.content.split("\n").first.start_with?('#!/')
  end

  def error_path(script)
    return script.error_path.to_s if script.error_path
    return script.output_path.to_s if script.output_path

    '/dev/null'
  end

  # under some conditions tmux returns status code 1 but it's not an actual
  # error. These are when the session is not found or there are no sessions
  # at all.
  def interpret_and_raise(error)
    if error.message.include?('failed to connect to server') # no sessions in tmux 1.8
      nil
    elsif error.message.include?('no server running on') # no sessions in tmux 2.7+ message
      nil
    else
      raise error
    end
  end

  def parse_hostname(output)
    output.split($/).map do |line|
      line[/^HOSTNAME:(.*)$/, 1]
    end.compact.last.to_s
  end
end
