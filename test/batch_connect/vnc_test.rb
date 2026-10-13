require 'test_helper'
require 'ood_core/batch_connect/templates/vnc'
require 'open3'
require 'tmpdir'

# The VNC template calls vncserver and vncpasswd. Sites can pin them to full
# paths so a user's PATH (e.g. a conda env from .bashrc) can't swap in other
# binaries (ood_core#208).
class BatchConnectVNCTest < Minitest::Test
  include TestHelper

  def build_template(context = {})
    OodCore::BatchConnect::Templates::VNC.new({ work_dir: '/tmp/work' }.merge(context))
  end

  def test_defaults_can_be_overridden_by_environment
    script = build_template.to_s

    assert_includes(script, '${VNCSERVER_CMD:-vncserver} -log')
    assert_includes(script, '${VNCSERVER_CMD:-vncserver} -kill')
    assert_includes(script, '${VNCPASSWD_CMD:-vncpasswd} -f')
  end

  def test_context_sets_full_paths_everywhere
    script = build_template(
      vncserver_cmd: '/opt/TurboVNC/bin/vncserver',
      vncpasswd_cmd: '/opt/TurboVNC/bin/vncpasswd'
    ).to_s

    # The stale-session cleanup (list + kill) runs in two places, the startup
    # loop and clean_up, so: 2 x 2, plus --help, start and the final kill.
    assert_equal(7, script.scan('/opt/TurboVNC/bin/vncserver').length)
    assert_equal(1, script.scan('/opt/TurboVNC/bin/vncpasswd').length)
  end

  def test_no_bare_vnc_commands_are_left
    script = build_template(vncserver_cmd: 'VNCSERVER', vncpasswd_cmd: 'VNCPASSWD').to_s
    code = script.lines.reject { |line| line.strip.start_with?('#') }.join

    refute_match(/\bvncserver\b/, code)
    refute_match(/\bvncpasswd\b/, code)
  end

  # The stale-session cleanup kills sessions from inside awk's system(),
  # which starts a new shell. A $VNCSERVER_CMD that was set but not exported
  # must still be the command that runs there, not whatever `vncserver` is
  # first on the PATH.
  def test_cleanup_uses_the_configured_command_even_when_not_exported
    Dir.mktmpdir do |dir|
      configured = fake_vncserver(dir, 'configured')
      on_path = fake_vncserver(dir, 'on_path')
      cleanup = build_template.send(:vnc_clean)

      script = <<~BASH
        PATH="#{File.dirname(on_path)}:$PATH"
        VNCSERVER_CMD="#{configured}"
        #{cleanup}
      BASH
      _out, status = Open3.capture2('bash', '-c', script)

      assert(status.success?)
      assert_equal(":1\n", read_kills(configured))
      assert_equal('', read_kills(on_path))
    end
  end

  def test_cleanup_only_kills_dead_sessions
    Dir.mktmpdir do |dir|
      vncserver = fake_vncserver(dir, 'plain')
      cleanup = build_template(vncserver_cmd: vncserver).send(:vnc_clean)

      _out, status = Open3.capture2('bash', '-c', cleanup)

      assert(status.success?)
      assert_equal(":1\n", read_kills(vncserver))
    end
  end

  private

  # A stand-in vncserver in its own directory. `-list` reports display :1
  # (a dead process) and :2 (this test process, alive); `-kill` records the
  # display it was asked to kill.
  def fake_vncserver(dir, name)
    bin = File.join(dir, name)
    Dir.mkdir(bin)
    path = File.join(bin, 'vncserver')
    File.write(path, <<~BASH)
      #!/bin/bash
      if [[ "$1" == "-list" ]]; then
        printf 'TurboVNC sessions:\\n\\nX DISPLAY #\\tPROCESS ID\\n:1\\t\\t999999\\n:2\\t\\t#{Process.pid}\\n'
      elif [[ "$1" == "-kill" ]]; then
        echo "$2" >> "#{path}.kills"
      fi
    BASH
    File.chmod(0o755, path)
    path
  end

  def read_kills(vncserver)
    kills = "#{vncserver}.kills"
    File.exist?(kills) ? File.read(kills) : ''
  end
end
