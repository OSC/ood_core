require 'test_helper'
require 'ood_core/batch_connect/templates/vnc'
require 'ood_core/batch_connect/templates/vnc_container'
require 'open3'
require 'socket'
require 'tmpdir'

# With :min_port or :max_port set, the VNC server should listen on a port in
# that range instead of on 5900 + its display number (ood_core#933).
#
# These run the template's VNC startup against a fake vncserver that records
# its arguments and reports display :7.
class BatchConnectVNCPortRangeTest < Minitest::Test
  include TestHelper

  def test_vnc_keeps_5900_plus_display_without_a_range
    result = start_vnc(OodCore::BatchConnect::Templates::VNC)

    assert_equal('5907', result[:port])
    refute_includes(result[:vncserver_args], '-rfbport')
  end

  def test_vnc_uses_a_port_in_the_range
    result = start_vnc(OodCore::BatchConnect::Templates::VNC, min_port: 41_000, max_port: 41_010)

    assert_includes(41_000..41_010, result[:port].to_i)
    assert_includes(result[:vncserver_args], "-rfbport #{result[:port]}")
    assert_equal('7', result[:display])
  end

  def test_vnc_skips_ports_in_use
    TCPServer.open('127.0.0.1', 41_020) do
      result = start_vnc(OodCore::BatchConnect::Templates::VNC, min_port: 41_020, max_port: 41_021)

      assert_equal('41021', result[:port])
    end
  end

  def test_either_end_of_the_range_is_enough
    result = start_vnc(OodCore::BatchConnect::Templates::VNC, max_port: 5000)

    assert_includes(2000..5000, result[:port].to_i)
  end

  def test_vnc_container_keeps_5900_plus_display_without_a_range
    result = start_vnc(OodCore::BatchConnect::Templates::VNC_Container)

    assert_equal('5907', result[:port])
    refute_includes(result[:vncserver_args], '-rfbport')
  end

  def test_vnc_container_uses_a_port_in_the_range
    result = start_vnc(OodCore::BatchConnect::Templates::VNC_Container, min_port: 41_030, max_port: 41_040)

    assert_includes(41_030..41_040, result[:port].to_i)
    assert_includes(result[:vncserver_args], "-rfbport #{result[:port]}")
  end

  private

  # Runs the template's startup (its bash helpers and before_script) with fake
  # vncserver, vncpasswd and singularity commands first on the PATH.
  def start_vnc(template_class, context = {})
    Dir.mktmpdir do |dir|
      bin = fake_commands(dir)
      template = template_class.new({ work_dir: dir }.merge(context))

      script = <<~BASH
        cd "#{dir}"
        PATH="#{bin}:$PATH"
        module () { :; }
        clean_up () { echo "clean_up called with ${1}"; exit 1; }
        #{template.send(:bash_helpers)}
        source_helpers
        host=localhost
        #{template.send(:before_script)}
        echo "port=${port} display=${display}"
        kill "$(cat "#{bin}/xvnc.pid")"
      BASH
      out, status = Open3.capture2e('bash', '-c', script)

      assert(status.success?, out)
      {
        port: out[/^port=(\S*)/, 1],
        display: out[/display=(\S*)/, 1],
        vncserver_args: File.read("#{bin}/vncserver.args")
      }
    end
  end

  def fake_commands(dir)
    bin = File.join(dir, 'bin')
    Dir.mkdir(bin)

    # The "Xvnc" it starts is a copy of sleep, so `pgrep Xvnc` finds it
    write_command(bin, 'vncserver', <<~BASH)
      case "$1" in
        -list|-kill|--help) exit 0 ;;
      esac
      echo "$@" > "#{bin}/vncserver.args"
      cp "$(command -v sleep)" "#{bin}/Xvnc"
      "#{bin}/Xvnc" 30 > /dev/null 2>&1 &
      echo $! > "#{bin}/xvnc.pid"
      echo "Desktop 'TurboVNC: localhost:7 (user)' started on display localhost:7"
    BASH
    write_command(bin, 'vncpasswd', 'cat > /dev/null')
    # `singularity exec instance://... cmd args` runs cmd args here
    write_command(bin, 'singularity', '[[ "$1" == "exec" ]] && shift 2 && exec "$@"; exit 0')
    bin
  end

  def write_command(bin, name, body)
    path = File.join(bin, name)
    File.write(path, "#!/bin/bash\n#{body}\n")
    File.chmod(0o755, path)
  end
end
