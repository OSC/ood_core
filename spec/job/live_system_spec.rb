require 'spec_helper'

describe 'a live system', :if => ENV['LIVE_CLUSTER_CONFIG'], :order => :defined do
  before(:all) do
    # load job config either from cluster config or from yaml in format { adapter:, ... }
    config = YAML.load_file(ENV['LIVE_CLUSTER_CONFIG'])
    @adapter = OodCore::Job::Factory.build(config.dig("v2", "job") || config)

    @script_content = <<~HERESCRIPT
      #!/bin/bash
      #JOB_HEADERS_HERE
      sleep 100
      exit 0
    HERESCRIPT

    @script = OodCore::Job::Script.new(
      # generate a random job name
      # e.g. TEST_SYQECQXW
      job_name: 'TEST_' + (0...8).map { (65 + rand(26)).chr }.join,
      content: @script_content,
      # don't clutter the file system with output from tests
      output_path: '/dev/null',
      error_path: '/dev/null',
      submit_as_hold: true
    )

    # Confirm that live tests will be run, and let the use know the name in case manual cleanup is necessary
    puts "\nRunning tests on live system with job_name #{@script.job_name}\n"
  end

  after(:all) do
    # Mark the boundry between live test outcomes and those of non-live system tests
    puts "\nLive system tests complete. Continuing with other tests:\n"
  end

  it('can submit') do
    $id = @adapter.submit(@script)
    expect($id).not_to be_empty
  end

  it('can get info') do
    # We can get info and that info is not default constructed
    expect(@adapter.info($id).job_name).to eq( @script.job_name )
  end

  it('can get status') do
    current_status = @adapter.status($id)
    expect(OodCore::Job::Status.states).to include(current_status)

    # Status is what we expect
    expect([:queued, :queued_held]).to include(current_status.state)
  end

  it("can find status of job in list of all user's jobs") do
    jobs = @adapter.info_where_owner(OodSupport::User.new.name)
    expect(jobs.map(&:id)).to include($id)
  end

  it('can release a held job') do
    @adapter.release($id)

    # The status is no longer held
    expect(@adapter.status($id).state).not_to eq(:queued_held)
  end

  it('can delete a job') do
    @adapter.delete($id)
  end
end
