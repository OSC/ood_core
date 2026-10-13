require 'test_helper'
require 'ood_core/batch_connect/templates/vnc_container'
require 'open3'
require 'tmpdir'

# The VNC server runs inside an apptainer/singularity instance, so stopping
# it has to happen inside the instance too (ood_core#931).
class BatchConnectVNCContainerTest < Minitest::Test
  def template(context = {})
    OodCore::BatchConnect::Templates::VNC_Container.new({ work_dir: '/tmp' }.merge(context))
  end

  def test_clean_script_kills_vnc_inside_the_container
    script = template.send(:clean_script)

    assert_includes(script, 'singularity exec instance://')
    refute_match(/&&\s+vncserver -kill/, script)
  end

  def test_clean_script_uses_configured_container_command
    script = template(container_command: 'apptainer').send(:clean_script)

    assert_includes(script, 'apptainer exec instance://')
    refute_includes(script, 'singularity exec instance://')
  end

  def test_clean_script_stops_the_instance_after_killing_vnc
    script = template.send(:clean_script)

    assert_operator(script.index('vncserver -kill'), :<, script.index('instance stop'))
  end

  # The kill used to happen twice: once from vnc_clean and again from a
  # second line, which then errored because the pid file was already gone.
  def test_clean_script_kills_once
    script = template.send(:clean_script)

    assert_equal(1, script.scan('vncserver -kill').length)
  end

  # vncserver -list inside the instance reports PIDs from the instance's PID
  # namespace, which mean nothing to kill -0 on the host. Kill by display.
  def test_cleanup_kills_only_this_jobs_display
    Dir.mktmpdir do |dir|
      container = fake_container(dir)
      tpl = template(container_command: container)
      cleanup = tpl.send(:vnc_clean)

      _out, status = Open3.capture2('bash', '-c', "display=2\n#{cleanup}")

      assert(status.success?)
      assert_equal(
        "exec instance://#{tpl.instance_variable_get(:@instance_name)} vncserver -kill :2\n",
        File.read("#{container}.calls")
      )
    end
  end

  # display is only set once the server has started, so cleanup in the
  # startup loop or after a failed start must not touch the container.
  def test_cleanup_does_nothing_before_the_server_starts
    Dir.mktmpdir do |dir|
      container = fake_container(dir)
      cleanup = template(container_command: container).send(:vnc_clean)

      Open3.capture2('bash', '-c', cleanup)

      refute(File.exist?("#{container}.calls"))
    end
  end

  private

  # A stand-in container command that records how it was called.
  def fake_container(dir)
    path = File.join(dir, 'container')
    File.write(path, <<~BASH)
      #!/bin/bash
      echo "$*" >> "#{path}.calls"
    BASH
    File.chmod(0o755, path)
    path
  end
end
