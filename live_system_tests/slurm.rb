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

  def test_that_it_is_working
    # We can submit
    id = @adapter.submit(get_job_script)
    
    # We can get info and that info is not default constructed
    assert_equal( @adapter.info(id).job_name, get_job_script.job_name )

    # We can get status
    current_status = @adapter.status(id)

    # Status is what we expect
    assert( current_status.queued? || current_status.queued_held? )

    # We can release a held job
    @adapter.release(id)

    # The status is no longer held
    assert( ! @adapter.status(id).queued_held? )

    # We can delete a job
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
      submit_as_hold: true
    )
  end
end


