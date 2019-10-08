require 'erb'
require 'etc'
require 'pathname'
require 'securerandom'
require 'shellwords'
require 'time'

# Object used for simplified communication SSH hosts
#
# @api private
class OodCore::Job::Adapters::LinuxHost::Launcher
  attr_reader :debug, :site_timeout, :session_name_label, :singularity_bin,
    :site_singularity_bindpath, :default_singularity_image, :ssh_hosts, 
    :strict_host_checking, :submit_host, :tmux_bin, :username
  # The root exception class that all LinuxHost adapter-specific exceptions inherit
  # from
  class Error < StandardError; end

  UNIT_SEPARATOR = "\x1F"

  # @param debug Whether the adapter should be used in debug mode
  # @param site_timeout [#to_i] A period after which the job should be killed or nil
  # @param singularity_bin  Path to the Singularity executable
  # @param singularity_bindpath A comma delimited string of host paths to bindmount into the guest; sets SINGULARITY_BINDPATH environment variable
  # @param singularity_image [#to_s] Path to the Singularity image
  # @param ssh_hosts List of hosts to check when scanning for running jobs
  # @param strict_host_checking Allow SSH to perform strict host checking
  # @param submit_host The SSH-able host
  # @param tmux_bin [#to_s] Path to the tmux executable
  def initialize(
    debug: false,
    site_timeout: nil,
    singularity_bin:,
    singularity_bindpath: '/etc,/media,/mnt,/opt,/srv,/usr,/var,/users',
    singularity_image:,
    ssh_hosts:,
    strict_host_checking: false,
    submit_host:,
    tmux_bin:,
    **_
  )
    @debug = !! debug
    @site_timeout = site_timeout.to_i
    @session_name_label = 'launched-by-ondemand'
    @singularity_bin = Pathname.new(singularity_bin)
    @site_singularity_bindpath = singularity_bindpath.to_s
    @default_singularity_image = Pathname.new(singularity_image)
    @ssh_hosts = ssh_hosts
    @strict_host_checking = strict_host_checking
    @submit_host = submit_host
    @tmux_bin = tmux_bin
    @username = Etc.getlogin
  end

  # @param hostname [#to_s] The hostname to submit the work to
  # @param script [OodCore::Job::Script] The script object defining the work
  def start_remote_session(script)
    unless user_script_has_shebang?(script)
      raise Error, 'User script must start with shebang'
    end
    cmd = ssh_cmd(submit_host)

    session_name = unique_session_name
    output = call(*cmd, stdin: wrapped_script(script, session_name))
    hostname = output.strip

    "#{session_name}@#{hostname}"
  end

  def stop_remote_session(session_name, hostname)
    cmd = ssh_cmd(hostname) + [tmux_bin, 'kill-session', '-t', session_name]
    call(*cmd)
  rescue Error => e
    raise e unless (
      # The tmux server not running is not an error
      e.message.include?('failed to connect to server') ||
      # The session not being found is not an error
      e.message.include?("session not found: #{session_name_label}")
    )
  end

  def list_remote_sessions(host: nil)
    host_list = (host) ? [host] : ssh_hosts

    host_list.map {
      |hostname| list_remote_tmux_session(hostname)
    }.flatten.sort_by {
      |hsh| hsh[:session_name]
    }
  end

  private

  # Call a forked Slurm command for a given cluster
  def call(cmd, *args, env: {}, stdin: "")
    args  = args.map(&:to_s)
    env = env.to_h
    o, e, s = Open3.capture3(env, cmd, *args, stdin_data: stdin.to_s)
    s.success? ? o : raise(Error, e)
  end

  # The SSH invocation to send a command
  # -t Force pseudo-terminal allocation (required to allow tmux to run)
  # -o BatchMode=yes (set mode to be non-interactive)
  # if ! strict_host_checking
  # -o UserKnownHostsFile=/dev/null (do not update the user's known hosts file)
  # -o StrictHostKeyChecking=no (do no check the user's known hosts file)
  def ssh_cmd(destination_host)
    if strict_host_checking
      [
        'ssh', '-t',
        '-o', 'BatchMode=yes',
        "#{username}@#{destination_host}"
      ]
    else
      [
        'ssh', '-t',
        '-o', 'BatchMode=yes',
        '-o', 'UserKnownHostsFile=/dev/null',
        '-o', 'StrictHostKeyChecking=no',
        "#{username}@#{destination_host}"
      ]
    end
  end

  # Wraps a user-provided script into a Tmux invocation
  def wrapped_script(script, session_name)
    ERB.new(
      File.read(Pathname.new(__dir__).join('templates/script_wrapper.erb.sh'))
    ).result(binding.tap {|bnd|
      {
        'arguments' => script_arguments(script),
        'cd_to_workdir' => (script.workdir) ? "cd #{script.workdir}" : '',
        'debug' => debug,
        'email_on_terminated' => script_email_on_event(script, 'terminated'),
        'email_on_start' => script_email_on_event(script, 'started'),
        'environment' => export_env(script.job_environment),
        'error_path' => (script.error_path) ? script.error_path.to_s : '/dev/null',
        'job_name' => script.job_name.to_s,
        'output_path' => (script.output_path) ? script.output_path.to_s : '/dev/null',
        'script_content' => script.content,
        'script_timeout' => script_timeout(script),
        'session_name' => session_name,
        'singularity_bin' => singularity_bin,
        'singularity_image' => singularity_image(script),
        'tmux_bin' => tmux_bin,
      }.each{
        |key, value| bnd.local_variable_set(key, value)
      }
    })
  end

  # Generate the environment export block for this script
  def export_env(environment)
    (environment ? environment : {}).tap{
      |hsh|
      hsh['SINGULARITY_BINDPATH'] = singularity_bindpath(environment)
      hsh.delete('SINGULARITY_CONTAINER')
    }.map{
      |key, value| "export #{key}=#{Shellwords.escape(value)}"
    }.sort.join("\n")
  end

  def singularity_image(script)
    image = script.job_environment['SINGULARITY_CONTAINER']
    (image) ? image : default_singularity_image
  end

  def singularity_bindpath(environment)
    script_bindpath = environment['SINGULARITY_BINDPATH']
    return script_bindpath if script_bindpath

    site_singularity_bindpath
  end

  def script_timeout(script)
    wall_time = script.wall_time.to_i
    return site_timeout if wall_time == 0
    return [wall_time, site_timeout].min unless site_timeout == 0

    wall_time
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
    "#{session_name_label}-#{SecureRandom.uuid}"
  end

  # List all Tmux sessions on destination_host started by this adapter
  # Additional tmux ls options available: http://man7.org/linux/man-pages/man1/tmux.1.html#FORMATS
  def list_remote_tmux_session(destination_host)
    # Note that the tmux variable substitution looks like Ruby string sub,
    # these must either be single quoted strings or Ruby-string escaped as well
    format_str = Shellwords.escape(
      ['#{session_name}', '#{session_created}', '#{pane_pid}'].join(UNIT_SEPARATOR)
    )
    keys = [:session_name, :session_created, :session_pid]
    cmd = ssh_cmd(destination_host) + ['tmux', 'list-panes', '-F', format_str]
    
    call(*cmd).split(
      "\n"
    ).map do |line|
      Hash[keys.zip(line.split(UNIT_SEPARATOR))].tap do |session_hash|
        session_hash[:destination_host] = destination_host
        session_hash[:id] = "#{session_hash[:session_name]}@#{destination_host}"
      end
    end.select{
      |session_hash| session_hash[:session_name].start_with?(session_name_label)
    }
  rescue Error => e
    # The tmux server not running is not an error
    raise e unless e.message.include?('failed to connect to server')
    []
  end

  def user_script_has_shebang?(script)
    return false if script.content.empty?
    script.content.split("\n").first.start_with?('#!/')
  end
end
