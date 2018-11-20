require 'spec_helper'

describe 'a live system', :if => (! ENV['LIVE_CLUSTER_CONFIG'].nil?) do
  before(:all) do
    @adapter = adapter = OodCore::Job::Factory.build(
      YAML.load_file(ENV['LIVE_CLUSTER_CONFIG'])
    )
    @script_content = <<~HERESCRIPT
      #!/bin/bash
      #JOB_HEADERS_HERE
      sleep 100
      exit 0
    HERESCRIPT
    @script = OodCore::Job::Script.new(
      # generate a random job name
      job_name: 'TEST_' + (0...8).map { (65 + rand(26)).chr }.join,
      content: @script_content,
      # don't clutter the file system with output from tests
      output_path: '/dev/null',
      error_path: '/dev/null',
      submit_as_hold: true
    )

    # Confirm that live tests will be run, and announce the job name for manual cleanup in case the test fails
    puts "\nRunning tests on live system with job_name #{@script.job_name}\n"
  end

  after(:all) do
    puts "\nLive system tests complete. Continuing with other tests:\n"
  end

  it('can perform submit, hold, release, info, status and delete') do
    # We can submit
    id = @adapter.submit(@script)
    expect(id).not_to be_empty

    # We can get info and that info is not default constructed
    expect(@adapter.info(id).job_name).to eq( @script.job_name )

    # We can get status
    current_status = @adapter.status(id)
    expect(current_status).not_to be_empty

    # Status is what we expect
    expect([:queued, :queued_held]).to include(current_status.state)

    # We can release a held job
    @adapter.release(id)

    # The status is no longer held
    expect(@adapter.status(id).state).not_to eq(:queued_held)

    # We can delete a job
    @adapter.delete(id)
  end
end