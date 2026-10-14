require 'test_helper'
require 'ood_core/batch_connect/templates/vnc'
require 'ood_core/batch_connect/templates/vnc_container'
require 'open3'
require 'tmpdir'
require 'fileutils'

# Runs the whole rendered job script, start to clean_up, against fake
# vncserver/websockify/container commands, and checks which displays get
# killed on each exit path. The unit tests check vnc_clean on its own; these
# check that clean_up actually reaches it with `display` set, and only then.
class BatchConnectVNCCleanupTest < Minitest::Test
  # Real TurboVNC's startup line, which the template parses for the display.
  DESKTOP_LINE = "Desktop 'TurboVNC: fakehost:%d (user)' started on display fakehost:%d"

  def setup
    # setsid and timeout are util-linux/coreutils; not on macOS by default
    %w[setsid timeout pgrep].each do |cmd|
      skip("needs #{cmd}") unless ENV['PATH'].split(':').any? { |d| File.executable?(File.join(d, cmd)) }
    end

    @dir = Dir.mktmpdir
    @bin = File.join(@dir, 'bin')
    @state = File.join(@dir, 'state')
    @work = File.join(@dir, 'work')
    FileUtils.mkdir_p([@bin, @state, @work])
    write_fakes
  end

  def teardown
    # Stop any fake Xvnc a failing test left behind
    Dir[File.join(@state, '*.pid')].each do |f|
      Process.kill('KILL', File.read(f).to_i) rescue nil
    end
    FileUtils.rm_rf(@dir)
  end

  def test_vnc_kills_its_display_once_when_the_script_exits
    status = run_job(:vnc, script_exit: 0)

    assert_equal(0, status.exitstatus, output)
    assert_equal([':1'], kills)
    refute(xvnc_alive?(1), 'Xvnc for :1 should be stopped')
  end

  def test_vnc_kills_its_display_when_the_script_fails
    status = run_job(:vnc, script_exit: 3)

    assert_equal(1, status.exitstatus, output)
    assert_equal([':1'], kills)
  end

  # clean_up 1 after the server started, from the websockify step
  def test_vnc_kills_its_display_when_websockify_fails
    status = run_job(:vnc, script_exit: 0, websockify: '/bin/false')

    assert_equal(1, status.exitstatus, output)
    assert_equal([':1'], kills)
  end

  # Real vncserver -kill with an empty display errors out ("Can't tell if :
  # is on <host>"), so with no server started nothing should be killed.
  def test_vnc_kills_nothing_when_the_server_never_starts
    status = run_job(:vnc, script_exit: 0, start_fails: true)

    assert_equal(1, status.exitstatus, output)
    assert_equal([], kills)
  end

  # Another of the user's jobs on the same node has its own live session,
  # and an old crashed one is still listed. Neither is this job's to clean
  # up. (The old -list sweep killed the stale one; that was dropped on
  # purpose, since in a container it couldn't tell live from dead.)
  def test_vnc_leaves_other_sessions_alone
    other = start_other_session(5)
    stale_session(6)

    run_job(:vnc, script_exit: 0)

    assert_equal([':1'], kills)
    assert(alive?(other), "the other job's session on :5 was killed")
  ensure
    Process.kill('KILL', other) rescue nil
  end

  def test_container_kills_its_display_inside_the_instance_then_stops_it
    status = run_job(:vnc_container, script_exit: 0)

    assert_equal(0, status.exitstatus, output)
    assert_equal([':1'], kills)
    calls = container_calls
    kill = calls.index { |c| c.include?('vncserver -kill') }
    stop = calls.index { |c| c.start_with?('instance stop') }
    refute_nil(kill, calls.join("\n"))
    assert_operator(kill, :<, stop)
    assert_match(%r{\Aexec instance://\S+ vncserver -kill :1\z}, calls[kill])
  end

  def test_container_kills_nothing_but_still_stops_the_instance_when_the_server_never_starts
    status = run_job(:vnc_container, script_exit: 0, start_fails: true)

    assert_equal(1, status.exitstatus, output)
    assert_equal([], kills)
    assert(container_calls.any? { |c| c.start_with?('instance stop') }, container_calls.join("\n"))
  end

  private

  def run_job(kind, script_exit:, websockify: nil, start_fails: false)
    File.write(File.join(@work, 'script.sh'), "#!/bin/bash\nexit #{script_exit}\n")
    File.chmod(0o755, File.join(@work, 'script.sh'))

    vncserver = File.join(@bin, start_fails ? 'vncserver-fails' : 'vncserver')
    script =
      if kind == :vnc
        OodCore::BatchConnect::Templates::VNC.new(
          work_dir: @work,
          vncserver_cmd: vncserver,
          vncpasswd_cmd: File.join(@bin, 'vncpasswd'),
          websockify_cmd: websockify || File.join(@bin, 'websockify')
        ).to_s
      else
        # Inside the fake instance, bare `vncserver` resolves via PATH
        FileUtils.ln_sf(vncserver, File.join(@bin, 'container-path', 'vncserver'))
        OodCore::BatchConnect::Templates::VNC_Container.new(
          work_dir: @work,
          container_command: 'fakecontainer',
          websockify_cmd: 'websockify'
        ).to_s
      end

    # The container template calls `module load`; sites provide it via Lmod
    script = "module () { :; }\n#{script}"
    env = {
      'PATH' => "#{@bin}/container-path:#{@bin}:#{ENV['PATH']}",
      'FAKE_STATE' => @state
    }
    # Each batch job runs in its own session, and the template relies on that
    # (`pgrep -s 0 Xvnc`), so give the job one here too.
    @output, status = Open3.capture2e(env, 'timeout', '60', 'setsid', '-w', 'bash', '-c', script, chdir: @work)
    status
  end

  attr_reader :output

  def kills
    file = File.join(@state, 'kills')
    File.exist?(file) ? File.read(file).split : []
  end

  def container_calls
    file = File.join(@state, 'container')
    File.exist?(file) ? File.read(file).lines.map(&:chomp) : []
  end

  def xvnc_alive?(display)
    file = File.join(@state, "#{display}.pid")
    File.exist?(file) && alive?(File.read(file).to_i)
  end

  def alive?(pid)
    Process.kill(0, pid)
    true
  rescue Errno::ESRCH
    false
  end

  # A live session from another job. It isn't in the job's session, just as
  # another job's processes wouldn't be.
  def start_other_session(display)
    pid = Process.spawn(File.join(@bin, 'Xvnc'), '300', %i[out err] => File::NULL)
    Process.detach(pid)
    File.write(File.join(@state, "#{display}.pid"), pid.to_s)
    pid
  end

  def stale_session(display)
    File.write(File.join(@state, "#{display}.pid"), '999999')
  end

  def write_fakes
    FileUtils.mkdir_p(File.join(@bin, 'container-path'))

    # The template finds the server with `pgrep -s 0 Xvnc`, which matches the
    # process name, so the fake server is `sleep` under the name Xvnc.
    sleep = ENV['PATH'].split(':').map { |d| File.join(d, 'sleep') }.find { |f| File.executable?(f) }
    FileUtils.ln_s(sleep, File.join(@bin, 'Xvnc'))

    fake(:vncserver, <<~BASH)
      state="$FAKE_STATE"
      case "$1" in
        --help|-help) echo "usage: vncserver ... -nohttpd"; exit 0 ;;
        -list)
          echo "TurboVNC sessions:"; echo; printf 'X DISPLAY #\\tPROCESS ID\\n'
          for f in "$state"/*.pid; do [[ -e $f ]] && printf ':%s\\t\\t%s\\n' "$(basename "$f" .pid)" "$(cat "$f")"; done
          exit 0 ;;
        -kill)
          d="${2#:}"
          if [[ -z $d ]]; then echo "Can't tell if $2 is on fakehost"; exit 2; fi
          echo "$2" >> "$state/kills"
          if [[ ! -e "$state/$d.pid" ]]; then echo "Can't find file $state/$d.pid"; exit 1; fi
          kill "$(cat "$state/$d.pid")" 2>/dev/null; rm -f "$state/$d.pid"; exit 0 ;;
      esac
      d=1; while [[ -e "$state/$d.pid" ]]; do d=$((d+1)); done
      nohup "$(dirname "$(readlink -f "$0")")/Xvnc" 300 >/dev/null 2>&1 &
      echo $! > "$state/$d.pid"
      echo; printf "#{DESKTOP_LINE}\\n" $d $d; echo
    BASH

    fake(:'vncserver-fails', <<~BASH)
      [[ "$1" == --help || "$1" == -help ]] && exit 0
      echo "Fatal server error: fake failure"; exit 1
    BASH

    fake(:vncpasswd, 'cat')

    # -D (container template) daemonizes; otherwise log the line the vnc
    # template waits for and stay up until clean_up kills it.
    fake(:websockify, <<~BASH)
      [[ "$1" == -D ]] && exit 0
      echo "WebSocket server settings: proxying from :$1 to $3"
      exec sleep 300
    BASH

    # `exec instance://NAME cmd...` runs cmd; instance start/stop just log.
    fake(:fakecontainer, <<~BASH)
      echo "$*" >> "$FAKE_STATE/container"
      [[ "$1" == exec ]] && { shift 2; exec "$@"; }
      exit 0
    BASH
  end

  def fake(name, body)
    path = File.join(@bin, name.to_s)
    File.write(path, "#!/bin/bash\n#{body}")
    File.chmod(0o755, path)
  end
end
