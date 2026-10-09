# test/batch_connect/templates/vnc_container_test.rb
require 'test_helper'
require 'ood_core/batch_connect/templates/vnc_container'

class VNCContainerTest < Minitest::Test
  def template(context = {})
    OodCore::BatchConnect::Templates::VNC_Container.new( { work_dir: '/tmp'}.merge(context) )
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
end