require 'bundler/setup'
require 'ood_core'
require 'minitest/autorun'

class TestLiveSystemSlurmAdapter < Minitest::Test
  def setup
    @adapter = OodCore::Job::Factory.build({
      :adapter => 'slurm',
      :bin => '/opt/slurm/bin',
      :conf => '/opt/slurm/etc/slurm.conf',
      :major_version => 18
    })
    @script_content = File.read('live_system_tests/bin/sleeper_job.sh')
  end

  def test_that_it_can_submit
    @adapter.submit(get_job_script)
  end

  def test_that_it_can_get_info_on_a_submitted_job
    id = @adapter.submit(get_job_script)
    
    assert_equal(
      @adapter.info(id).job_name,
      get_job_script.job_name
    )
  end

  def test_that_ids_returned_by_submit_are_valid_for_delete
    id = @adapter.submit(get_job_script)
    
    @adapter.delete(id)
  end

  private

  def get_job_script(iteration: 0)
    script = OodCore::Job::Script.new(
      job_name: "job_#{iteration.to_s.rjust(3, '0')}",
      content: @script_content,
      # don't clutter the file system with output from tests
      output_path: '/dev/null',
      error_path: '/dev/null',
    )
  end
end


