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
    result = start_vnc(vncserver_output: nil)

    refute(result[:success])
    assert_includes(result[:out], "ERROR: vncserver isn't in PATH.")
    refute_includes(result[:out], 'command not found')
  end

  def test_vnc_container_names_tigervnc_in_the_container
    result = start_vnc(OodCore::BatchConnect::Templates::VNC_Container, vncserver_output: TIGERVNC_OUTPUT)

    refute(result[:success])
    assert_equal(1, result[:attempts])
    assert_includes(result[:out], 'The vncserver in the container (vnc_container.sif) is TigerVNC')
  end

  def test_vnc_container_reports_missing_vncserver
    result = start_vnc(OodCore::BatchConnect::Templates::VNC_Container, vncserver_output: nil)

    refute(result[:success])
    assert_includes(result[:out], "ERROR: vncserver isn't in PATH in the container")
  end

  private

  # Runs the template's startup (its bash helpers and before_script) with a
  # fake vncserver that prints vncserver_output and fails. With
  # vncserver_output nil, there's no vncserver at all. The PATH is only the
  # fake commands, so a real vncserver on this machine can't get in the way.
  def start_vnc(template_class = OodCore::BatchConnect::Templates::VNC, vncserver_output:)
    Dir.mktmpdir do |dir|
      bin = fake_commands(dir, vncserver_output)
      template = template_class.new(work_dir: dir)

      script = <<~BASH
        cd "#{dir}"
        PATH="#{bin}"
        module () { :; }
        clean_up () { echo "clean_up called with ${1}"; exit 1; }
        #{template.send(:bash_helpers)}
        source_helpers
        host=localhost
        #{template.send(:before_script)}
      BASH
      out, status = Open3.capture2e('/bin/bash', '-c', script)
      attempts = File.exist?("#{bin}/attempts") ? File.read("#{bin}/attempts").lines.size : 0

      { success: status.success?, out: out, attempts: attempts }
    end
  end

  def fake_commands(dir, vncserver_output)
    bin = File.join(dir, 'bin')
    Dir.mkdir(bin)
    # the few real commands the startup loop uses
    %w[cat grep pgrep seq shuf sleep sh].each do |cmd|
      path = ENV['PATH'].split(':').map { |p| File.join(p, cmd) }.find { |p| File.executable?(p) }
      File.symlink(path, File.join(bin, cmd))
    end

    write_command(bin, 'vncpasswd', '/bin/cat > /dev/null')
    write_command(bin, 'singularity', '[[ "$1" == "exec" ]] && shift 2 && exec "$@"; exit 0')
    unless vncserver_output.nil?
      write_command(bin, 'vncserver', <<~BASH)
        case "$1" in
          -list|-kill|--help) exit 0 ;;
        esac
        echo try >> "#{bin}/attempts"
        printf '%s' '#{vncserver_output}'
        exit 1
      BASH
    end
    bin
  end

  def write_command(bin, name, body)
    path = File.join(bin, name)
    File.write(path, "#!/bin/bash\n#{body}\n")
    File.chmod(0o755, path)
  end
end
