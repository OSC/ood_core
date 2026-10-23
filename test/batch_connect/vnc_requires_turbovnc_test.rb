require 'test_helper'
require 'ood_core/batch_connect/templates/vnc'
require 'ood_core/batch_connect/templates/vnc_container'
require 'open3'
require 'tmpdir'

# VNC apps need TurboVNC. When vncserver is missing or is TigerVNC, the job
# should say so instead of retrying ten times and dumping usage text
# (ood_core#768).
class BatchConnectVNCRequiresTurboVNCTest < Minitest::Test
  include TestHelper

  TIGERVNC_OUTPUT = <<~OUT.freeze
    Xvnc TigerVNC 1.13.1 - built 2024-04-01 08:26
    Unrecognized option: -Log
    vncserver: /usr/bin/Xtigervnc exited with status 1
  OUT

  # The deprecation warning some RHEL-family TigerVNC packages print; unlike
  # most of their output, it doesn't say "TigerVNC"
  RHEL_STUB_OUTPUT = <<~OUT.freeze
    WARNING: vncserver has been replaced by a systemd unit and is about to be removed in future releases.
  OUT

  def test_tigervnc_is_named_and_not_retried
    result = start_vnc(vncserver_output: TIGERVNC_OUTPUT)

    refute(result[:success])
    assert_equal(1, result[:attempts])
    assert_includes(result[:out], 'is TigerVNC, but VNC apps need')
  end

  def test_rhel_systemd_stub_is_treated_as_tigervnc
    result = start_vnc(vncserver_output: RHEL_STUB_OUTPUT)

    refute(result[:success])
    assert_equal(1, result[:attempts])
    assert_includes(result[:out], 'is TigerVNC, but VNC apps need')
  end

  def test_other_failures_still_retry_without_blaming_tigervnc
    result = start_vnc(vncserver_output: "Could not start Xvnc.\n")

    refute(result[:success])
    assert_equal(10, result[:attempts])
    assert_includes(result[:out], 'ERROR: Could not start the VNC server.')
    refute_includes(result[:out], 'TigerVNC')
  end

  def test_missing_vncserver_is_reported_before_trying
    skip_if_real_vncserver_in_path

    result = start_vnc(vncserver_output: nil)

    refute(result[:success])
    assert_includes(result[:out], 'ERROR: VNC server command not found: vncserver')
    refute_includes(result[:out], 'vncserver: command not found')
  end

  # vncserver_cmd (VNCSERVER_CMD) can pin vncserver to a path outside PATH;
  # the up-front check has to look there, not in PATH
  def test_pinned_vncserver_outside_path_is_found
    result = start_vnc(vncserver_output: TIGERVNC_OUTPUT, pin_vncserver: true)

    refute(result[:success])
    refute_includes(result[:out], 'VNC server command not found')
    assert_equal(1, result[:attempts])
    assert_includes(result[:out], 'is TigerVNC, but VNC apps need')
  end

  def test_missing_pinned_vncserver_is_reported
    result = start_vnc(vncserver_output: nil, pin_vncserver: true)

    refute(result[:success])
    assert_match(%r{ERROR: VNC server command not found: \S+/pinned/vncserver}, result[:out])
  end

  def test_vnc_container_names_tigervnc_in_the_container
    result = start_vnc(OodCore::BatchConnect::Templates::VNC_Container, vncserver_output: TIGERVNC_OUTPUT)

    refute(result[:success])
    assert_equal(1, result[:attempts])
    assert_includes(result[:out], 'The vncserver in the container (vnc_container.sif) is TigerVNC')
  end

  def test_vnc_container_reports_missing_vncserver
    skip_if_real_vncserver_in_path

    result = start_vnc(OodCore::BatchConnect::Templates::VNC_Container, vncserver_output: nil)

    refute(result[:success])
    assert_includes(result[:out], "ERROR: vncserver isn't in PATH in the container")
  end

  private

  # Runs the template's startup (its bash helpers and before_script) with a
  # fake vncserver that prints vncserver_output and fails. With
  # vncserver_output nil, there's no fake vncserver at all. The fake commands
  # go first in PATH, so they win over anything installed on this machine.
  # With pin_vncserver, the fake vncserver goes in a directory that isn't in
  # PATH and VNCSERVER_CMD points at it.
  def start_vnc(template_class = OodCore::BatchConnect::Templates::VNC, vncserver_output:, pin_vncserver: false)
    Dir.mktmpdir do |dir|
      bin = fake_commands(dir)
      attempts_file = File.join(dir, 'attempts')

      vncserver_dir = bin
      if pin_vncserver
        vncserver_dir = File.join(dir, 'pinned')
        Dir.mkdir(vncserver_dir)
      end
      write_vncserver(vncserver_dir, vncserver_output, attempts_file) unless vncserver_output.nil?

      pin_line = pin_vncserver ? %(export VNCSERVER_CMD="#{vncserver_dir}/vncserver") : ''
      template = template_class.new(work_dir: dir)

      # Written to a file rather than passed with `bash -c`, so the script
      # isn't one huge argument
      script_file = File.join(dir, 'start_vnc.sh')
      File.write(script_file, <<~BASH)
        cd "#{dir}"
        PATH="#{bin}:${PATH}"
        #{pin_line}
        module () { :; }
        clean_up () { echo "clean_up called with ${1}"; exit 1; }
        #{template.send(:bash_helpers)}
        source_helpers
        host=localhost
        #{template.send(:before_script)}
      BASH

      out, status = Open3.capture2e('/bin/bash', script_file)
      attempts = File.exist?(attempts_file) ? File.read(attempts_file).lines.size : 0

      { success: status.success?, out: out, attempts: attempts }
    end
  end

  def fake_commands(dir)
    bin = File.join(dir, 'bin')
    Dir.mkdir(bin)
    write_command(bin, 'vncpasswd', '/bin/cat > /dev/null')
    write_command(bin, 'singularity', '[[ "$1" == "exec" ]] && shift 2 && exec "$@"; exit 0')
    # the retry loop sleeps up to 0.9s after each failed start; skip that here
    write_command(bin, 'sleep', 'exit 0')
    bin
  end

  def write_vncserver(dir, output, attempts_file)
    write_command(dir, 'vncserver', <<~BASH)
      case "$1" in
        -list|-kill|--help) exit 0 ;;
      esac
      echo try >> "#{attempts_file}"
      printf '%s' '#{output}'
      exit 1
    BASH
  end

  def write_command(dir, name, body)
    path = File.join(dir, name)
    File.write(path, "#!/bin/bash\n#{body}\n")
    File.chmod(0o755, path)
  end

  # The "missing vncserver" tests can't hide one that's really installed
  # (the fake commands only go in front of PATH), so skip them there; CI
  # has no vncserver and still runs them
  def skip_if_real_vncserver_in_path
    real = ENV['PATH'].split(':').map { |p| File.join(p, 'vncserver') }.find { |p| File.executable?(p) }
    skip("a real vncserver is in PATH (#{real})") if real
  end
end
