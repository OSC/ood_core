require 'test_helper'

class TestSlurm < Minitest::Test
  include TestHelper

  def slurm_instance(config = {})
    OodCore::Job::Factory.build({ adapter: 'slurm' }.merge(config))
  end

  def test_submit_interface
    slurm = slurm_instance

    assert(slurm.respond_to?(:submit))
    veryify_keywords(slurm, :submit, [:after, :afterok, :afternotok, :afterany])
    verify_args(slurm, :submit, 1)
  end

  def test_submitting_with_hold
    slurm = slurm_instance
    stub_submit
    OodCore::Job::Adapters::Slurm::Batch.any_instance.expects(:submit_string).with(script_content, args: ["-H", "--export", "NONE"], env: {})
    slurm.submit(build_script(submit_as_hold: true))
  end
end
