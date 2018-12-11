require 'spec_helper'

describe 'a live system', :if => ENV['LIVE_CLUSTER_CONFIG'], :order => :defined do
  before(:context) { @list = [] }
  before(:all) do
    @adapter = OodCore::Job::Factory.build(
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
    @list << 1
    $id = @adapter.submit(@script)
    expect($id).not_to be_empty
  end

  it('can get info') do
    @list << 2
    # We can get info and that info is not default constructed
    expect(@adapter.info($id).job_name).to eq( @script.job_name )
  end

  it('can get status') do
    @list << 3
    current_status = @adapter.status($id)
    expect(OodCore::Job::Status.states).to include(current_status)

    # Status is what we expect
    expect([:queued, :queued_held]).to include(current_status.state)
  end

  it('can release a held job') do
    @list << 4
    @adapter.release($id)

    # The status is no longer held
    expect(@adapter.status($id).state).not_to eq(:queued_held)
  end

  it('can delete a job') do
    @list << 5
    @adapter.delete($id)
  end
end