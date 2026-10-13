require 'test_helper'
require 'open3'
require 'socket'
require 'tempfile'

# Runs the rendered bash helpers against real sockets. The port checks in
# ood_core#926 were wrong about ports held by outgoing connections, which only
# shows up when there is an actual socket to find.
class BatchConnectTemplateTest < Minitest::Test
  include TestHelper

  def setup
    skip('needs /proc/net/tcp (Linux)') unless File.readable?('/proc/net/tcp')

    template = OodCore::BatchConnect::Template.new(work_dir: '/tmp/work')
    @helpers = Tempfile.new(['bash_helpers', '.sh'])
    @helpers.write(template.send(:bash_helpers))
    @helpers.flush

    # Every socket a test opens goes here so teardown can close it.
    @sockets = []
  end

  def teardown
    # setup may have skipped before creating these.
    if @sockets
      @sockets.each do |socket|
        socket.close unless socket.closed?
      end
    end

    @helpers.close! if @helpers
  end

  # Source the helpers, run cmd, and return [stdout, exit status]. Capped with
  # timeout(1) so a check that hangs (connect-based ones can, see #926) fails
  # with status 124 instead of stalling the suite.
  def run_helper(cmd)
    script = "source #{@helpers.path}; source_helpers; #{cmd}"
    out, status = Open3.capture2('timeout', '10', 'bash', '-c', script)
    [out.strip, status.exitstatus]
  end

  # Just the exit status of run_helper, for tests that don't check output.
  def helper_status(cmd)
    _out, status = run_helper(cmd)
    status
  end

  # Port 0 asks the kernel for any free port; this reads back which one it gave.
  def port_of(socket)
    socket.local_address.ip_port
  end

  # A listening socket on a kernel-chosen port. Never accepts connections.
  def listener(host = '127.0.0.1')
    server = TCPServer.new(host, 0)
    @sockets << server
    server
  end

  # A port nothing is using. Picked from below the kernel's ephemeral range,
  # because ports in that range get handed to other processes' outgoing
  # connections at any moment (the #926 case), which made this flaky on busy
  # login nodes.
  def free_port
    range = File.read('/proc/sys/net/ipv4/ip_local_port_range').split
    ephemeral_low = range.first.to_i

    (ephemeral_low - 1).downto(1024) do |port|
      return port if nothing_bound_to?(port)
    end

    flunk("no free port found below the ephemeral range (#{ephemeral_low})")
  end

  # Binds without SO_REUSEADDR (TCPServer sets it), on 0.0.0.0, so the bind
  # fails if any IPv4 socket in any state holds this port.
  def nothing_bound_to?(port)
    socket = Socket.new(:INET, :STREAM)
    socket.bind(Addrinfo.tcp('0.0.0.0', port))
    true
  rescue Errno::EADDRINUSE, Errno::EACCES
    false
  ensure
    socket.close if socket
  end

  # The local port of an outgoing connection: in use, but nothing listens on it.
  # This is the case #926 is about.
  def outgoing_connection_port
    server = listener
    client = TCPSocket.new('127.0.0.1', port_of(server))
    accepted = server.accept
    @sockets << client
    @sockets << accepted
    port_of(client)
  end

  def test_port_used_detects_listening_port
    port = port_of(listener)

    assert_equal(0, helper_status("port_used localhost:#{port}"))
  end

  def test_port_used_detects_port_held_by_outgoing_connection
    port = outgoing_connection_port

    assert_equal(0, helper_status("port_used localhost:#{port}"))
  end

  def test_port_used_reports_free_port
    port = free_port

    assert_equal(1, helper_status("port_used localhost:#{port}"))
  end

  def test_port_used_proc_reads_tcp6
    skip('needs /proc/net/tcp6') unless File.readable?('/proc/net/tcp6')
    port = port_of(listener('::1'))

    assert_equal(0, helper_status("port_used_proc localhost #{port}"))
  end

  # ss only runs when /proc/net is unreadable, so exercise it directly.
  def test_port_used_ss
    skip('needs ss') unless system('command -v ss >/dev/null 2>&1')
    used = outgoing_connection_port
    free = free_port

    assert_equal(0, helper_status("port_used_ss localhost #{used}"))
    assert_equal(1, helper_status("port_used_ss localhost #{free}"))
  end

  def test_find_port_skips_port_held_by_outgoing_connection
    port = outgoing_connection_port
    out, status = run_helper("find_port localhost #{port} #{port} 2>/dev/null")

    assert_equal(1, status)
    assert_equal('', out)
  end

  def test_find_port_returns_free_port
    port = free_port
    out, status = run_helper("find_port localhost #{port} #{port}")

    assert_equal(0, status)
    assert_equal(port.to_s, out)
  end
end
