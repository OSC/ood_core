require 'test_helper'
require 'ood_core/batch_connect/templates/vnc'

class BatchConnectTemplateTest < Minitest::Test
  def test_makes_script_file_executable_before_running_it
    template = OodCore::BatchConnect::Template.new(
      work_dir: '/tmp',
      script_file: './script with spaces.sh'
    )

    assert_includes(
      template.to_s,
      "bash -c '[[ -x \"$1\" ]] || chmod +x \"$1\"; exec \"$1\"' -- \"./script with spaces.sh\" &"
    )
  end

  def test_custom_run_script_does_not_change_permissions
    template = OodCore::BatchConnect::Template.new(
      work_dir: '/tmp',
      run_script: 'custom-command'
    )

    assert_includes template.to_s, 'custom-command &'
    refute_includes template.to_s, 'chmod +x'
  end

  def test_overridden_run_script_does_not_change_permissions
    template_class = Class.new(OodCore::BatchConnect::Template) do
      private

      def run_script
        'custom-command'
      end
    end

    template = template_class.new(work_dir: '/tmp')

    assert_includes template.to_s, 'custom-command &'
    refute_includes template.to_s, 'chmod +x'
  end

  def test_vnc_preserves_display_environment
    template = OodCore::BatchConnect::Templates::VNC.new(
      work_dir: '/tmp',
      script_file: './script.sh'
    )

    assert_includes template.to_s, "DISPLAY=:${display} bash -c '[[ -x \"$1\" ]] || chmod +x \"$1\"; exec \"$1\"' -- \"./script.sh\" &"
  end
end
