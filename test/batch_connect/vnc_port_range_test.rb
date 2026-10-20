require 'test_helper'
require 'ood_core/batch_connect/templates/vnc'
require 'ood_core/batch_connect/templates/vnc_container'
require 'open3'
require 'tmpdir'

# With :min_port or :max_port set, the VNC server should listen on a port in
# that range instead of on 5900 + its display number (ood_core#933).
#
# Most of these only read the generated script. The last two run the
# template's startup against a fake vncserver, to show the port it picks is
# the one vncserver gets and the one the job reports. Skipping ports already
# in use is find_port's job and is tested in template_test.rb.
class BatchConnectVNCPortRangeTest < Minitest::Test
  include TestHelper

  TEMPLATES = [
    OodCore::BatchConnect::Templates::VNC,
    OodCore::BatchConnect::Templates::VNC_Container
  ].freeze

  def test_without_a_range_the_port_is_5900_plus_display
    TEMPLATES.each do |template_class|
      script = before_script(template_class)

      assert_includes(script, 'port=$((5900+display))', template_class.name)
      refute_includes(script, '-rfbport', template_class.name)
      refute_includes(script, 'find_port', template_class.name)
    end
  end

  def test_with_a_range_a_free_port_in_it_is_passed_to_vncserver
    TEMPLATES.each do |template_class|
      script = before_script(template_class, min_port: 41_000, max_port: 41_010)

      assert_includes(script, 'port=$(find_port localhost 41000 41010) || clean_up 1', template_class.name)
      assert_includes(script, '-noxstartup -rfbport ${port} ', template_class.name)
      refute_includes(script, 'port=$((5900+display))', template_class.name)
    end
  end

  def test_the_port_is_picked_before_vncserver_starts
    TEMPLATES.each do |template_class|
      script = before_script(template_class, min_port: 41_000, max_port: 41_010)

      assert_operator(script.index('find_port localhost'), :<, script.index('-rfbport'), template_class.name)
    end
  end

  def test_either_end_of_the_range_is_enough
    TEMPLATES.each do |template_class|
      only_max = before_script(template_class, max_port: 5000)
      only_min = before_script(template_class, min_port: 41_000)

      assert_includes(only_max, 'find_port localhost 2000 5000', template_class.name)
      assert_includes(only_min, 'find_port localhost 41000 65535', template_class.name)
    end
  end

  def test_vnc_starts_on_the_picked_port
    result = start_vnc(OodCore::BatchConnect::Templates::VNC, min_port: 41_000, max_port: 41_010)

    assert_includes(41_000..41_010, result[:port].to_i)
    assert_includes(result[:vncserver_args], "-rfbport #{result[:port]}")
    assert_equal('7', result[:display])
  end

  def test_vnc_container_starts_on_the_picked_port
    result = start_vnc(OodCore::BatchConnect::Templates::VNC_Container, min_port: 41_030, max_port: 41_040)

    assert_includes(41_030..41_040, result[:port].to_i)
    assert_includes(result[:vncserver_args], "-rfbport #{result[:port]}")
    assert_equal('7', result[:display])
  end

  private

  def before_script(template_class, context = {})
    template = template_class.new({ work_dir: '/tmp/work' }.merge(context))
    template.send(:before_script)
  end

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
      BASH
      # Lmod sets BASH_ENV so `module` works in scripts, which makes every
      # bash here source its init first. That's slow on a cluster login node
      # and not needed: `module` is stubbed above.
      env = { 'BASH_ENV' => nil, 'ENV' => nil }
      # A hang should fail the test, not stall the suite.
      out, status = Open3.capture2e(env, 'timeout', '30', 'bash', '-c', script)

      refute_equal(124, status.exitstatus, "timed out:\n#{out}")
      assert(status.success?, out)
      {
        port: out[/^port=(\S*)/, 1],
        display: out[/display=(\S*)/, 1],
        vncserver_args: File.read(File.join(bin, 'vncserver.args'))
      }
    ensure
      stop_fake_xvnc(bin) if bin
    end
  end

  def fake_commands(dir)
    bin = File.join(dir, 'bin')
    Dir.mkdir(bin)
    sleep = ENV['PATH'].split(':').map { |d| File.join(d, 'sleep') }.find { |f| File.executable?(f) }
    FileUtils.cp(sleep, File.join(bin, 'Xvnc'))

    # The "Xvnc" it starts is a copy of sleep, so `pgrep Xvnc` finds it
    write_command(bin, 'vncserver', <<~BASH)
      case "$1" in
        -list|-kill|--help) exit 0 ;;
      esac
      echo "$@" > "#{bin}/vncserver.args"
      "#{bin}/Xvnc" 30 > /dev/null 2>&1 &
      xvnc=$!
      echo $xvnc >> "#{bin}/xvnc.pids"
      # Real vncserver doesn't return until Xvnc is up. Without this wait
      # the template's `pgrep -s 0 Xvnc` can run first on a busy machine,
      # see no server, and start another one.
      for i in $(seq 500); do
        read -r comm < /proc/$xvnc/comm 2>/dev/null
        [[ $comm == Xvnc ]] && break
        sleep 0.01
      done
      echo "Desktop 'TurboVNC: localhost:7 (user)' started on display localhost:7"
    BASH
    write_command(bin, 'vncpasswd', 'cat > /dev/null')
    # `singularity exec instance://... cmd args` runs cmd args here
    write_command(bin, 'singularity', '[[ "$1" == "exec" ]] && shift 2 && exec "$@"; exit 0')
    bin
  end

  # Stop every fake Xvnc this test started, even if it failed partway
  def stop_fake_xvnc(bin)
    pids = File.join(bin, 'xvnc.pids')
    return unless File.exist?(pids)

    File.read(pids).split.each do |pid|
      Process.kill('KILL', pid.to_i)
    rescue Errno::ESRCH
      next
    end
  end

  def write_command(bin, name, body)
    path = File.join(bin, name)
    File.write(path, "#!/bin/bash\n#{body}\n")
    File.chmod(0o755, path)
  end
end
