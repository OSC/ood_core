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
end
