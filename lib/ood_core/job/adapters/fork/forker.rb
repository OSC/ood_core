require 'erb'
require 'etc'
require 'pathname'
require 'securerandom'
require 'shellwords'
require 'time'
# Object used for simplified communication SSH hosts
#
# @api private
class OodCore::Job::Adapters::Fork::Forker
  # The root exception class that all Fork adapter-specific exceptions inherit
  # from
  class Error < StandardError; end

  UNIT_SEPARATOR = "\x1F"

  # @param tmux_bin [#to_s] Path to the tmux executable
  # @param timeout [#to_i] A period after which the job should be killed or nil
  def initialize(tmux_bin:, max_timeout: nil, ssh_hosts:, submit_host:, debug: false, **_)
    @debug = !! debug
    @max_timeout = max_timeout.to_i
    @session_name_label = 'launched-by-ondemand'
    @ssh_hosts = ssh_hosts
    @submit_host = submit_host
    @tmux_bin = Pathname.new(tmux_bin)
    @username = Etc.getlogin
  end

  # @param hostname [#to_s] The hostname to submit the work to
  # @param script [OodCore::Job::Script] The script object defining the work
  def start_remote_tmux_session(script)
    cmd = ssh_cmd(@submit_host)
    session_name = unique_session_name

    output = call(*cmd, stdin: wrapped_script(script, session_name))
    hostname = output.split("\n").first

    "#{session_name}@#{hostname}"
  end

  def stop_remote_tmux_session(hostname:, session_name:)
    cmd = ssh_cmd(hostname) + [@tmux_bin, 'kill-session', '-t', session_name]
    call(*cmd)
  rescue Error => e
    # The Tmux server not running is not an error
    raise e unless e.message.include?('failed to connect to server')
  end

  def list_remote_tmux_sessions(host: nil)
    host_list = (host) ? [host] : @ssh_hosts

    host_list.map {
      |hostname| list_remote_tmux_session(hostname)
    }.flatten.sort
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
  def ssh_cmd(destination_host)
    ['ssh', '-t', '-o', 'BatchMode=yes', "#{@username}@#{destination_host}"]
  end

  # Wraps a user-provided script into a Tmux invocation
  def wrapped_script(script, session_name)
    ERB.new(
      File.read(Pathname.new(__dir__).join('script_wrapper.erb.sh'))
    ).result(binding.tap {|bnd|
      {
        'cd_to_workdir' => (script.workdir) ? "cd #{script.workdir}" : '',
        'debug' => @debug,
        'environment' => export_env(script.job_environment),
        'error_path' => (script.error_path) ? script.error_path.to_s : '/dev/null',
        'output_path' => (script.output_path) ? script.output_path.to_s : '/dev/null',
        'script_content' => script.content,
        'session_name' => session_name,
        'timeout_cmd' => timeout_killer_cmd(script.wall_time),
        'tmux_bin' => @tmux_bin,
      }.each{
        |key, value| bnd.local_variable_set(key, value)
      }
    })
  end

  # Nuke the current process after @timeout seconds
  def timeout_killer_cmd(script_timeout)
    if @max_timeout == 0
      ''
    else
      # TODO: Handle requested timeout that's longer than system configured timeout by raising Error
      timeout = (@max_timeout < script_timeout.to_i ) ? @max_timeout : script_timeout.to_i
      current_pid = Shellwords.escape('$$')
      <<~HEREDOC
        {
        sleep #{timeout}
        kill -9 #{current_pid}
        } &
      HEREDOC
    end
  end

  def unique_session_name
    "#{@session_name_label}-#{SecureRandom.uuid}"
  end

  # Generate the environment export block for this script
  def export_env(environment)
    # TODO: Need to confirm that quotes are handled properly for value
    (environment ? environment : {}).map{
      |key, value| "export #{key}=#{Shellwords.escape(value)}"
    }.join("\n")
  end

  # List all Tmux sessions on destination_host started by this adapter
  # Additional tmux ls options available: http://man7.org/linux/man-pages/man1/tmux.1.html#FORMATS
  def list_remote_tmux_session(destination_host)
    # Note that the tmux variable substitution looks like Ruby string sub,
    # these must either be single quoted strings or Ruby-string escaped as well
    format_str = Shellwords.escape(
      ['#{session_name}', '#{session_created}'].join(UNIT_SEPARATOR)
    )
    keys = [:session_name, :session_created]
    cmd = ssh_cmd(destination_host) + ['tmux', 'list-sessions', '-F', format_str]
    
    call(*cmd).split(
      "\n"
    ).map do |line|
      Hash[keys.zip(line.split(UNIT_SEPARATOR))].tap do |session_hash|
        session_hash[:destination_host] = destination_host
        session_hash[:id] = "#{session_hash[:session_name]}@#{destination_host}"
      end
    end.select{
      |session_hash| session_hash[:session_name].start_with?(@session_name_label)
    }
  rescue Error => e
    # The Tmux server not running is not an error
    raise e unless e.message.include?('failed to connect to server')
    []
  end
end
