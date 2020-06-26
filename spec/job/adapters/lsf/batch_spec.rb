require "ood_core/job/adapters/lsf"
require "ood_core/job/adapters/lsf/batch"
require "timecop"

describe OodCore::Job::Adapters::Lsf::Batch do
  subject(:batch) { described_class.new() }

  #TODO: consider using contexts http://betterspecs.org/#contexts
  describe "#parse_bsub_output" do
    # parse bsubmit output
    it "should correctly parse bsub output" do
      expect(batch.parse_bsub_output "Job <542935> is submitted to queue <short>.\n").to eq "542935"
    end
  end

  describe "#parse_bjobs_output" do
    it "handles nil" do
      expect(batch.parse_bjobs_output nil).to eq []
    end

    it "handles empty string" do
      expect(batch.parse_bjobs_output "").to eq []
    end

    # this test is not valid because "No job found\n" etc. appear in
    # stderr not stdout
    # it "handles no jobs in output" do
    #   expect(batch.parse_bjobs_output "No job found\n").to eq []
    #   expect(batch.parse_bjobs_output "No unfinished job found\n").to eq []
    # end

    it "raises exception for unexpected columns" do
      # I added ANOTHER_COLUMN to the end of this
      output = <<-OUTPUT
JOBID   USER    STAT  QUEUE
542935  efranz  RUN   short
      OUTPUT
      expect { batch.parse_bjobs_output output }.to raise_error(OodCore::Job::Adapters::Lsf::Batch::Error)
    end

    it "parses output for one job" do
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

    it "parses output for two jobs" do
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

    it "parses output for piped script with no jobname" do
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

    it "parses output for one job in LSF 9.1" do
      output = <<-OUTPUT
JOBID      USER    STAT  QUEUE      FROM_HOST   EXEC_HOST   JOB_NAME   SUBMIT_TIME  PROJ_NAME CPU_USED MEM SWAP PIDS START_TIME FINISH_TIME SLOTS
5861085 efranz  RUN   sn_xlong   login5      sx6036-1402 u256-1     06/15-16:48:55 082848040736 165:53:45.00 114    0      17435,17555,17559,17719 06/15-16:48:56 -  1
      OUTPUT
      expect(batch.parse_bjobs_output(output)).to eq([{
        id: "5861085",
        user: "efranz",
        status: "RUN",
        queue: "sn_xlong",
        from_host: "login5",
        exec_host: "sx6036-1402",
        name: "u256-1",
        submit_time: "06/15-16:48:55",
        project: "082848040736",
        cpu_used: "165:53:45.00",
        mem:"114",
        swap:"0",
        pids:"17435,17555,17559,17719",
        start_time: "06/15-16:48:56",
        finish_time: nil,

        # FIXME: we omit slots right now to make it easier to deal with both
        # plus we can calculate the total number of slots in the LSF details pane
        # slots: "1"
       }])
    end

  describe "#default_env" do
    subject(:batch) { described_class.new(config).default_env }

    context "when {}" do
      let(:config) { {}  }
      it { is_expected.to eq({}) }
    end

    context "when bindir set" do
      let(:config) { { bindir: "/opt/lsf/8.3/bin" } }
      it { is_expected.to eq({"LSF_BINDIR" => "/opt/lsf/8.3/bin"}) }
    end

    context "when envdir set" do
      let(:config) { { envdir: "/opt/lsf/conf" } }
      it { is_expected.to eq({"LSF_ENVDIR" => "/opt/lsf/conf"}) }
    end

    context "when bindir, libdir, envdir, and serverdir set" do
      let(:config) {
        {
          bindir: "/opt/lsf/8.3/bin",
          libdir: "/opt/lsf/8.3/lib",
          envdir: "/opt/lsf/conf",
          serverdir: "/opt/lsf/8.3/etc"
        }
      }

      it { is_expected.to eq(
        {
          "LSF_BINDIR" => "/opt/lsf/8.3/bin",
          "LSF_LIBDIR" => "/opt/lsf/8.3/lib",
          "LSF_ENVDIR" =>"/opt/lsf/conf",
          "LSF_SERVERDIR" =>"/opt/lsf/8.3/etc"
        }
      )}
    end
  end

  describe "multinode" do
    subject(:batch) { described_class.new(config).cluster_args }
    context "when cluster not set" do
      let(:config) {
        {
          bindir: "/opt/lsf/8.3/bin",
          libdir: "/opt/lsf/8.3/lib",
          envdir: "/opt/lsf/conf",
          serverdir: "/opt/lsf/8.3/etc"
        }
      }
      it { is_expected.to eq([]) }
    end
    context "when cluster not set" do
      let(:config) {
        {
          bindir: "/opt/lsf/8.3/bin",
          libdir: "/opt/lsf/8.3/lib",
          envdir: "/opt/lsf/conf",
          serverdir: "/opt/lsf/8.3/etc",
          cluster: "curie"
        }
      }
      it { is_expected.to eq(["-m", "curie"]) }
    end
  end

  describe "customizing bin paths" do
    let(:script) { OodCore::Job::Script.new(content: "echo 'hi'") }

    context "when calling with no config" do
      it "uses the correct command" do
        batch = OodCore::Job::Adapters::Lsf::Batch.new
        allow(Open3).to receive(:capture3).and_return(["job.123", "", double("success?" => true)])

        batch.submit_string(str: script.content)
        expect(Open3).to have_received(:capture3).with(anything, "bsub", any_args)
      end
    end

    context "when calling with normal config" do
      it "uses the correct command" do
        batch = OodCore::Job::Adapters::Lsf::Batch.new(bindir: "/bin", bin_overrides: {})
        allow(Open3).to receive(:capture3).and_return(["job.123", "", double("success?" => true)])

        batch.submit_string(str: script.content)
        expect(Open3).to have_received(:capture3).with(anything, "/bin/bsub", any_args)
      end
    end

    context "when calling with overrides" do
      it "uses the correct command" do
        batch = OodCore::Job::Adapters::Lsf::Batch.new(bin_overrides: {"bsub" => "not_bsub"})
        allow(Open3).to receive(:capture3).and_return(["job.123", "", double("success?" => true)])

        batch.submit_string(str: script.content)
        expect(Open3).to have_received(:capture3).with(anything, "not_bsub", any_args)
      end
    end
  end


  describe "setting submit_host" do 
    let(:script) { OodCore::Job::Script.new(content: "echo 'hi'") }

    context "when calling without submit_host" do 
      it "uses the correct command" do 
        batch = OodCore::Job::Adapters::Lsf::Batch.new
        allow(Open3).to receive(:capture3).and_return(["job.123", "", double("success?" => true)])

        batch.submit_string(str: script.content)
        expect(Open3).to have_received(:capture3).with(anything, "bsub", any_args)
      end
    end

    context "when calling with submit_host" do 
      it "uses ssh wrapper" do 
        batch = OodCore::Job::Adapters::Lsf::Batch.new(submit_host: 'owens.osc.edu')
        allow(Open3).to receive(:capture3).and_return(["job.123", "", double("success?" => true)])

        batch.submit_string(str: script.content)
        expect(Open3).to have_received(:capture3).with(anything, 'ssh', '-o', 'BatchMode=yes', '-o', 'UserKnownHostsFile=/dev/null', '-o', 'StrictHostKeyChecking=yes', 'owens.osc.edu', 'bsub', any_args)
      end
    end

  end
end
