require "spec_helper"
require "ood_core/job/adapters/lsf"

describe OodCore::Job::Adapters::Lsf do
  # Required arguments
  let(:config) { {} }

  # Subject
  subject(:adapter) { described_class.new(config) }

  it { is_expected.to respond_to(:submit).with(0).arguments.and_keywords(:script, :after, :afterok, :afternotok, :afterany) }
  it { is_expected.to respond_to(:info).with(0).arguments.and_keywords(:id) }
  it { is_expected.to respond_to(:status).with(0).arguments.and_keywords(:id) }
  it { is_expected.to respond_to(:hold).with(0).arguments.and_keywords(:id) }
  it { is_expected.to respond_to(:release).with(0).arguments.and_keywords(:id) }
  it { is_expected.to respond_to(:delete).with(0).arguments.and_keywords(:id) }

  #TODO: mixing tests for lsf batch; lets move this to module
  describe "Batch#parse_bsub_output" do
    subject(:batch) { OodCore::Job::Adapters::Lsf::Batch.new() }

    # parse bsubmit output
    it "should correctly parse bsub output" do
      expect(batch.parse_bsub_output "Job <542935> is submitted to queue <short>.\n").to eq "542935"
    end
  end

  # parse_bjobs_output
  describe "Batch#parse_bjobs_output" do
    subject(:batch) { OodCore::Job::Adapters::Lsf::Batch.new() }
    let(:job_hash) {
    }


    it "should handle no jobs in output" do
      expect(batch.parse_bjobs_output "No job found\n").to eq [{}]
    end

    it "should raise exception for unexpected columns" do
      # I added ANOTHER_COLUMN to the end of this
      output = <<-OUTPUT
JOBID   USER    STAT  QUEUE
542935  efranz  RUN   short
      OUTPUT
      expect { batch.parse_bjobs_output output }.to raise_error(OodCore::Job::Adapters::Lsf::Batch::Error)
    end

    it "should parse output for one job" do
      output = <<-OUTPUT
JOBID   USER    STAT  QUEUE      FROM_HOST   EXEC_HOST   JOB_NAME   SUBMIT_TIME  PROJ_NAME CPU_USED MEM SWAP PIDS START_TIME FINISH_TIME
542935  efranz  RUN   short      foobar02.osc.edu compute013  foo        03/31-14:46:42 default    000:00:00.00 2      32     25156 03/31-14:46:44 -
      OUTPUT
      expect(batch.parse_bjobs_output(output)).to eq([{
        id: "542935",
        user: "efranz",
        status: "RUN",
        queue: "short",
        from_host: "foobar02.osc.edu",
        exec_host: "compute013",
        name: "foo",
        submit_time: "03/31-14:46:42",
        project: "default",
        cpu_used: "000:00:00.00",
        mem:"2",
        swap:"32",
        pids:"25156",
        start_time: "03/31-14:46:44",
        finish_time: nil
       }])
    end

    it "should parse output for two jobs" do
      output = <<-OUTPUT
JOBID   USER    STAT  QUEUE      FROM_HOST   EXEC_HOST   JOB_NAME   SUBMIT_TIME  PROJ_NAME CPU_USED MEM SWAP PIDS START_TIME FINISH_TIME
542935  efranz  RUN   short      foobar02.osc.edu compute013  foo        03/31-14:46:42 default    000:00:00.00 2      32     25156 03/31-14:46:44 -
542936  efranz  RUN   short      foobar02.osc.edu compute014  bar        03/31-14:46:42 default    000:00:00.00 2      32     25156 03/31-14:46:44 -
      OUTPUT
      expect(batch.parse_bjobs_output(output)).to eq([{
        id: "542935",
        user: "efranz",
        status: "RUN",
        queue: "short",
        from_host: "foobar02.osc.edu",
        exec_host: "compute013",
        name: "foo",
        submit_time: "03/31-14:46:42",
        project: "default",
        cpu_used: "000:00:00.00",
        mem:"2",
        swap:"32",
        pids:"25156",
        start_time: "03/31-14:46:44",
        finish_time: nil
       },{
        id: "542936",
        user: "efranz",
        status: "RUN",
        queue: "short",
        from_host: "foobar02.osc.edu",
        exec_host: "compute014",
        name: "bar",
        submit_time: "03/31-14:46:42",
        project: "default",
        cpu_used: "000:00:00.00",
        mem:"2",
        swap:"32",
        pids:"25156",
        start_time: "03/31-14:46:44",
        finish_time: nil

       }])
    end

    it "should parse output for piped script with no jobname" do
      output = <<-OUTPUT
JOBID   USER    STAT  QUEUE      FROM_HOST   EXEC_HOST   JOB_NAME   SUBMIT_TIME  PROJ_NAME CPU_USED MEM SWAP PIDS START_TIME FINISH_TIME
542945  efranz  DONE  short      foobar02.osc.edu compute013  #!/bin/bash;#;#BSUB -q short # queue;#BSUB -e myjob.%J.err;#BSUB -o myjob.%J.out; echo "Hello world, I am in $PWD";sleep 30;echo "Goodbye, world!" 03/31-19:24:57 default    000:00:00.03 2      32     9389 03/31-19:24:59 03/31-19:25:29
OUTPUT
      expect(batch.parse_bjobs_output(output)).to eq([{
        id: "542945",
        user: "efranz",
        status: "DONE",
        queue: "short",
        from_host: "foobar02.osc.edu",
        exec_host: "compute013",
        name: "#!/bin/bash;#;#BSUB -q short # queue;#BSUB -e myjob.%J.err;#BSUB -o myjob.%J.out; echo \"Hello world, I am in $PWD\";sleep 30;echo \"Goodbye, world!\"",
        submit_time: "03/31-19:24:57",
        project: "default",
        cpu_used: "000:00:00.03",
        mem:"2",
        swap:"32",
        pids:"9389",
        start_time: "03/31-19:24:59",
        finish_time: "03/31-19:25:29"
       }])
    end
  end
end