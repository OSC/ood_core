require "spec_helper"
require "ood_core/job/adapters/slurm"

describe OodCore::Job::Adapters::Slurm do
  # Required arguments
  let(:slurm) { double() }

  # Subject
  subject(:adapter) { described_class.new(slurm: slurm) }

  it { is_expected.to respond_to(:submit).with(0).arguments.and_keywords(:script, :after, :afterok, :afternotok, :afterany) }
  it { is_expected.to respond_to(:info).with(0).arguments.and_keywords(:id) }
  it { is_expected.to respond_to(:status).with(0).arguments.and_keywords(:id) }
  it { is_expected.to respond_to(:hold).with(0).arguments.and_keywords(:id) }
  it { is_expected.to respond_to(:release).with(0).arguments.and_keywords(:id) }
  it { is_expected.to respond_to(:delete).with(0).arguments.and_keywords(:id) }

  describe ".new" do
    context "when :slurm not defined" do
      subject { described_class.new }

      it "raises ArgumentError" do
        expect { subject }.to raise_error(ArgumentError)
      end
    end
  end

  describe "#submit" do
    def build_script(opts = {})
      OodCore::Job::Script.new(
        {
          content: content
        }.merge opts
      )
    end

    let(:slurm) { double(submit_string: "job.123") }
    let(:content) { "my batch script" }

    context "when :script not defined" do
      it "raises ArgumentError" do
        expect { adapter.submit }.to raise_error(ArgumentError)
      end
    end

    subject { adapter.submit(script: build_script) }

    it "returns job id" do
      is_expected.to eq("job.123")
      expect(slurm).to have_received(:submit_string).with(content, args: [], env: {})
    end

    context "with :queue_name" do
      before { adapter.submit(script: build_script(queue_name: "queue")) }

      it { expect(slurm).to have_received(:submit_string).with(content, args: ["-p", "queue"], env: {}) }
    end

    context "with :args" do
      before { adapter.submit(script: build_script(args: ["arg1", "arg2"])) }

      it { expect(slurm).to have_received(:submit_string).with(content, args: [], env: {}) }
    end

    context "with :submit_as_hold" do
      context "as true" do
        before { adapter.submit(script: build_script(submit_as_hold: true)) }

        it { expect(slurm).to have_received(:submit_string).with(content, args: ["-H"], env: {}) }
      end

      context "as false" do
        before { adapter.submit(script: build_script(submit_as_hold: false)) }

        it { expect(slurm).to have_received(:submit_string).with(content, args: [], env: {}) }
      end
    end

    context "with :rerunnable" do
      context "as true" do
        before { adapter.submit(script: build_script(rerunnable: true)) }

        it { expect(slurm).to have_received(:submit_string).with(content, args: ["--requeue"], env: {}) }
      end

      context "as false" do
        before { adapter.submit(script: build_script(rerunnable: false)) }

        it { expect(slurm).to have_received(:submit_string).with(content, args: ["--no-requeue"], env: {}) }
      end
    end

    context "with :job_environment" do
      before { adapter.submit(script: build_script(job_environment: {"key" => "value"})) }

      it { expect(slurm).to have_received(:submit_string).with(content, args: ["--export", "key"], env: {"key" => "value"}) }
    end

    context "with :workdir" do
      before { adapter.submit(script: build_script(workdir: "/path/to/workdir")) }

      it { expect(slurm).to have_received(:submit_string).with(content, args: ["-D", "/path/to/workdir"], env: {}) }
    end

    context "with :email" do
      before { adapter.submit(script: build_script(email: ["email1", "email2"])) }

      it { expect(slurm).to have_received(:submit_string).with(content, args: ["--mail-user", "email1,email2"], env: {}) }
    end

    context "with :email_on_started" do
      context "as true" do
        before { adapter.submit(script: build_script(email_on_started: true)) }

        it { expect(slurm).to have_received(:submit_string).with(content, args: ["--mail-type", "BEGIN"], env: {}) }
      end

      context "as false" do
        before { adapter.submit(script: build_script(email_on_started: false)) }

        it { expect(slurm).to have_received(:submit_string).with(content, args: [], env: {}) }
      end
    end

    context "with :email_on_terminated" do
      context "as true" do
        before { adapter.submit(script: build_script(email_on_terminated: true)) }

        it { expect(slurm).to have_received(:submit_string).with(content, args: ["--mail-type", "END"], env: {}) }
      end

      context "as false" do
        before { adapter.submit(script: build_script(email_on_terminated: false)) }

        it { expect(slurm).to have_received(:submit_string).with(content, args: [], env: {}) }
      end
    end

    context "with :email_on_started and :email_on_terminated" do
      before { adapter.submit(script: build_script(email_on_started: true, email_on_terminated: true)) }

      it { expect(slurm).to have_received(:submit_string).with(content, args: ["--mail-type", "ALL"], env: {}) }
    end

    context "with :job_name" do
      before { adapter.submit(script: build_script(job_name: "my_job")) }

      it { expect(slurm).to have_received(:submit_string).with(content, args: ["-J", "my_job"], env: {}) }
    end

    context "with :input_path" do
      before { adapter.submit(script: build_script(input_path: "/path/to/input")) }

      it { expect(slurm).to have_received(:submit_string).with(content, args: ["-i", Pathname.new("/path/to/input")], env: {}) }
    end

    context "with :output_path" do
      before { adapter.submit(script: build_script(output_path: "/path/to/output")) }

      it { expect(slurm).to have_received(:submit_string).with(content, args: ["-o", Pathname.new("/path/to/output")], env: {}) }
    end

    context "with :error_path" do
      before { adapter.submit(script: build_script(error_path: "/path/to/error")) }

      it { expect(slurm).to have_received(:submit_string).with(content, args: ["-e", Pathname.new("/path/to/error")], env: {}) }
    end

    context "with :join_files" do
      context "as true" do
        before { adapter.submit(script: build_script(join_files: true)) }

        it { expect(slurm).to have_received(:submit_string).with(content, args: [], env: {}) }
      end

      context "as false" do
        before { adapter.submit(script: build_script(join_files: false)) }

        it { expect(slurm).to have_received(:submit_string).with(content, args: [], env: {}) }
      end
    end

    context "with :reservation_id" do
      before { adapter.submit(script: build_script(reservation_id: "my_rsv")) }

      it { expect(slurm).to have_received(:submit_string).with(content, args: ["--reservation", "my_rsv"], env: {}) }
    end

    context "with :priority" do
      before { adapter.submit(script: build_script(priority: 123)) }

      it { expect(slurm).to have_received(:submit_string).with(content, args: ["--priority", 123], env: {}) }
    end

    context "with :start_time" do
      before { adapter.submit(script: build_script(start_time: Time.new(2016, 11, 8, 13, 53, 54).to_i)) }

      it { expect(slurm).to have_received(:submit_string).with(content, args: ["--begin", "2016-11-08T13:53:54"], env: {}) }
    end

    context "with :accounting_id" do
      before { adapter.submit(script: build_script(accounting_id: "my_account")) }

      it { expect(slurm).to have_received(:submit_string).with(content, args: ["-A", "my_account"], env: {}) }
    end

    context "with :min_phys_memory" do
      before { adapter.submit(script: build_script(min_phys_memory: 1234)) }

      it { expect(slurm).to have_received(:submit_string).with(content, args: ["--mem", "1234K"], env: {}) }
    end

    context "with :wall_time" do
      before { adapter.submit(script: build_script(wall_time: 94534)) }

      it { expect(slurm).to have_received(:submit_string).with(content, args: ["-t", "26:15:34"], env: {}) }
    end

    context "with :nodes" do
      context "as single node name" do
        before { adapter.submit(script: build_script(nodes: "node")) }

        it { expect(slurm).to have_received(:submit_string).with(content, args: [], env: {}) }
      end

      context "as single node request object" do
        before { adapter.submit(script: build_script(nodes: {procs: 12, properties: ["prop1", "prop2"]})) }

        it { expect(slurm).to have_received(:submit_string).with(content, args: [], env: {}) }
      end

      context "as a list of nodes" do
        before { adapter.submit(script: build_script(nodes: ["node1"] + [{procs: 12}]*4 + ["node2", {procs: 45, properties: "prop"}])) }

        it { expect(slurm).to have_received(:submit_string).with(content, args: [], env: {}) }
      end
    end

    context "with :native" do
      before { adapter.submit(script: build_script(native: ["A", "B", "C"])) }

      it { expect(slurm).to have_received(:submit_string).with(content, args: ["A", "B", "C"], env: {}) }
    end

    %i(after afterok afternotok afterany).each do |after|
      context "and :#{after} is defined as a single job id" do
        before { adapter.submit(script: build_script, after => "job_id") }

        it { expect(slurm).to have_received(:submit_string).with(content, args: ["-d", "#{after}:job_id"], env: {}) }
      end

      context "and :#{after} is defined as multiple job ids" do
        before { adapter.submit(script: build_script, after => ["job1", "job2"]) }

        it { expect(slurm).to have_received(:submit_string).with(content, args: ["-d", "#{after}:job1:job2"], env: {}) }
      end
    end

    context "when OodCore::Job::Adapters::Slurm::Batch::Error is raised" do
      before { expect(slurm).to receive(:submit_string).and_raise(OodCore::Job::Adapters::Slurm::Batch::Error) }

      it "raises OodCore::JobAdapterError" do
        expect { subject }.to raise_error(OodCore::JobAdapterError)
      end
    end
  end

  describe "#info" do
    context "when :id is not defined" do
      let(:slurm) { double(get_jobs: {}) }
      subject { adapter.info }

      it "returns an array of all the jobs" do
        is_expected.to eq([])
        expect(slurm).to have_received(:get_jobs).with(id: "")
      end
    end

    let(:job_id)   { "job_id" }
    let(:job_hash) { {} }
    let(:slurm)    { double(get_jobs: [job_hash]) }
    subject { adapter.info(id: double(to_s: job_id)) }

    context "when job is not running" do
      let(:job_hash) {
        {
          :account=>"mah-kp",
          :job_id=>job_id,
          :gres=>"(null)",
          :exec_host=>"n/a",
          :min_cpus=>"1",
          :cpus=>"24",
          :min_tmp_disk=>"0",
          :nodes=>"1",
          :end_time=>"2017-04-04T22:13:03",
          :dependency=>"",
          :features=>"(null)",
          :array_job_id=>"2449921",
          :group_name=>"mah",
          :group_id=>"4000097",
          :over_subscribe=>"NO",
          :sockets_per_node=>"*",
          :cores_per_socket=>"*",
          :job_name=>"jobname.err",
          :threads_per_core=>"*",
          :comment=>"(null)",
          :array_task_id=>"N/A",
          :time_limit=>"3-00:00:00",
          :time_left=>"3-00:00:00",
          :min_memory=>"0",
          :time_used=>"0:00",
          :req_node=>"",
          :node_list=>"",
          :command=>"/uufs/chpc.utah.edu/common/home/u0549046/king3/run/happel20/job_slurm",
          :contiguous=>"0",
          :qos=>"mah-kp",
          :partition=>"mah-kp",
          :priority=>"102808",
          :reason=>"Resources",
          :start_time=>"2017-04-01T22:13:03",
          :state_compact=>"PD",
          :state=>"PENDING",
          :user=>"u0549046",
          :user_id=>"624953",
          :reservation=>"(null)",
          :submit_time=>"2017-03-30T13:28:01",
          :wckey=>"(null)",
          :licenses=>"(null)",
          :excluded_nodes=>"",
          :core_specialization=>"N/A",
          :nice=>"0",
          :scheduled_nodes=>"(null)",
          :sockets_cores_threads=>"*:*:*",
          :work_dir=>"/uufs/chpc.utah.edu/common/home/u0549046/king3/run/happel20"
        }
      }

      it "returns correct OodCore::Job::Info object" do
        is_expected.to eq(OodCore::Job::Info.new(
          :id=>job_id,
          :status=>:queued,
          :allocated_nodes=>[],
          :submit_host=>nil,
          :job_name=>"jobname.err",
          :job_owner=>"u0549046",
          :accounting_id=>"mah-kp",
          :procs=>24,
          :queue_name=>"mah-kp",
          :wallclock_time=>0,
          :cpu_time=>nil,
          :submission_time=>Time.parse("2017-03-30T13:28:01"),
          :dispatch_time=>Time.parse("2017-04-01T22:13:03"),
          :native=>job_hash
        ))
      end
    end

    context "when job is running" do
      let(:job_hash) {
        {
          :account=>"hooper",
          :job_id=>job_id,
          :gres=>"(null)",
          :exec_host=>"kp002",
          :min_cpus=>"1",
          :cpus=>"256",
          :min_tmp_disk=>"0",
          :nodes=>"14",
          :end_time=>"2017-04-02T10:21:59",
          :dependency=>"",
          :features=>"(null)",
          :array_job_id=>"2448023",
          :group_name=>"hooper",
          :group_id=>"4000175",
          :over_subscribe=>"NO",
          :sockets_per_node=>"*",
          :cores_per_socket=>"*",
          :job_name=>"big_CB7CB_330Knptall_modTD",
          :threads_per_core=>"*",
          :comment=>"(null)",
          :array_task_id=>"N/A",
          :time_limit=>"3-00:00:00",
          :time_left=>"2-01:44:25",
          :min_memory=>"64000M",
          :time_used=>"22:15:35",
          :req_node=>"",
          :node_list=>"kp[002,006,026-029,158-159,162-164,197-199]",
          :command=>"/uufs/chpc.utah.edu/common/home/u0135669/Dima_CB7CB/big_CB7CB_330K_nptall_modTD/sluK_king",
          :contiguous=>"0",
          :qos=>"kingspeak",
          :partition=>"kingspeak",
          :priority=>"109809",
          :reason=>"None",
          :start_time=>"2017-03-30T10:21:54",
          :state_compact=>"R",
          :state=>"RUNNING",
          :user=>"u0135669",
          :user_id=>"204994",
          :reservation=>"(null)",
          :submit_time=>"2017-03-29T13:51:05",
          :wckey=>"(null)",
          :licenses=>"(null)",
          :excluded_nodes=>"",
          :core_specialization=>"N/A",
          :nice=>"0",
          :scheduled_nodes=>"(null)",
          :sockets_cores_threads=>"*:*:*",
          :work_dir=>"/uufs/chpc.utah.edu/common/home/u0135669/Dima_CB7CB/big_CB7CB_330K_nptall_modTD"
        }
      }

      it "returns correct OodCore::Job::Info object" do
        is_expected.to eql(OodCore::Job::Info.new(
          :id=>job_id,
          :status=>:running,
          :allocated_nodes=>[
            {:name=>"kp002", :procs=>nil},
            {:name=>"kp006", :procs=>nil},
            {:name=>"kp026", :procs=>nil},
            {:name=>"kp027", :procs=>nil},
            {:name=>"kp028", :procs=>nil},
            {:name=>"kp029", :procs=>nil},
            {:name=>"kp158", :procs=>nil},
            {:name=>"kp159", :procs=>nil},
            {:name=>"kp162", :procs=>nil},
            {:name=>"kp163", :procs=>nil},
            {:name=>"kp164", :procs=>nil},
            {:name=>"kp197", :procs=>nil},
            {:name=>"kp198", :procs=>nil},
            {:name=>"kp199", :procs=>nil}
          ],
          :submit_host=>nil,
          :job_name=>"big_CB7CB_330Knptall_modTD",
          :job_owner=>"u0135669",
          :accounting_id=>"hooper",
          :procs=>256,
          :queue_name=>"kingspeak",
          :wallclock_time=>80135,
          :cpu_time=>nil,
          :submission_time=>Time.parse("2017-03-29T13:51:05"),
          :dispatch_time=>Time.parse("2017-03-30T10:21:54"),
          :native=>job_hash
        ))
      end
    end

    context "when dealing with job array" do
      let(:job_hash) {
        {
          :job_id=>"123",
          :array_job_id=>"123",
          :array_task_id=>"0-3,8,10",
          :array_job_task_id=>"123_[0-3,8,10]",
          :state_compact=>"PD",
          :reason=>"JobHeldUser,Resources",
          :start_time=>"N/A",
          :submit_time=>"2017-03-31T10:09:44"
        }
      }
      let(:child_job_hash) {
        {
          :job_id=>"124",
          :array_job_id=>"123",
          :array_task_id=>"6",
          :array_job_task_id=>"123_6",
          :state_compact=>"R",
          :reason=>"None",
          :start_time=>"N/A",
          :submit_time=>"2017-03-31T10:09:44"
        }
      }

      context "and job id is array job id" do
        let(:job_id)   { "123" }
        let(:slurm)    { double(get_jobs: [child_job_hash, job_hash]) }

        it "returns correct OodCore::Job::Info object" do
          is_expected.to eq(OodCore::Job::Info.new(
            :id=>"123",
            :status=>:queued,
            :allocated_nodes=>[],
            :submit_host=>nil,
            :job_name=>nil,
            :job_owner=>nil,
            :accounting_id=>nil,
            :procs=>nil,
            :queue_name=>nil,
            :wallclock_time=>0,
            :cpu_time=>nil,
            :submission_time=>Time.parse("2017-03-31T10:09:44"),
            :dispatch_time=>nil,
            :native=>job_hash
          ))
        end
      end

      context "and job id is formatted array job and task id" do
        let(:job_id)   { "123_6" }
        let(:slurm)    { double(get_jobs: [child_job_hash]) }

        it "returns correct OodCore::Job::Info object" do
          is_expected.to eq(OodCore::Job::Info.new(
            :id=>"124",
            :status=>:running,
            :allocated_nodes=>[],
            :submit_host=>nil,
            :job_name=>nil,
            :job_owner=>nil,
            :accounting_id=>nil,
            :procs=>nil,
            :queue_name=>nil,
            :wallclock_time=>0,
            :cpu_time=>nil,
            :submission_time=>Time.parse("2017-03-31T10:09:44"),
            :dispatch_time=>nil,
            :native=>child_job_hash
          ))
        end
      end
    end

    context "when can't find job" do
      let(:slurm) { double(get_jobs: []) }

      it "returns completed OodCore::Job::Info object" do
        is_expected.to eq(OodCore::Job::Info.new(id: job_id, status: :completed))
      end
    end

    context "when OodCore::Job::Adapters::Slurm::Batch::Error is raised" do
      before { expect(slurm).to receive(:get_jobs).and_raise(OodCore::Job::Adapters::Slurm::Batch::Error) }

      it "raises OodCore::JobAdapterError" do
        expect { subject }.to raise_error(OodCore::JobAdapterError)
      end
    end
  end

  describe "#status" do
    context "when :id is not defined" do
      it "raises ArgumentError" do
        expect { adapter.status }.to raise_error(ArgumentError)
      end
    end

    let(:job_state) { "" }
    let(:job_id)    { "job_id" }
    let(:slurm)     { double(get_jobs: [job_id: job_id, array_job_task_id: job_id, state_compact: job_state]) }
    subject { adapter.status(id: double(to_s: job_id)) }

    it "request only job state from OodCore::Job::Adapters::Slurm::Batch" do
      subject
      expect(slurm).to have_received(:get_jobs).with(id: job_id, filters: [:job_id, :array_job_task_id, :state_compact])
    end

    context "when job is in BF state" do
      let(:job_state) { "BF" }

      it { is_expected.to be_completed }
    end

    context "when job is in CA state" do
      let(:job_state) { "CA" }

      it { is_expected.to be_completed }
    end

    context "when job is in CD state" do
      let(:job_state) { "CD" }

      it { is_expected.to be_completed }
    end

    context "when job is in CF state" do
      let(:job_state) { "CF" }

      it { is_expected.to be_queued }
    end

    context "when job is in CG state" do
      let(:job_state) { "CG" }

      it { is_expected.to be_running }
    end

    context "when job is in F state" do
      let(:job_state) { "F" }

      it { is_expected.to be_completed }
    end

    context "when job is in NF state" do
      let(:job_state) { "NF" }

      it { is_expected.to be_completed }
    end

    context "when job is in PR state" do
      let(:job_state) { "PR" }

      it { is_expected.to be_completed }
    end

    context "when job is in RV state" do
      let(:job_state) { "RV" }

      it { is_expected.to be_completed }
    end

    context "when job is in R state" do
      let(:job_state) { "R" }

      it { is_expected.to be_running }
    end

    context "when job is in SE state" do
      let(:job_state) { "SE" }

      it { is_expected.to be_completed }
    end

    context "when job is in ST state" do
      let(:job_state) { "ST" }

      it { is_expected.to be_running }
    end

    context "when job is in S state" do
      let(:job_state) { "S" }

      it { is_expected.to be_suspended }
    end

    context "when job is in TO state" do
      let(:job_state) { "TO" }

      it { is_expected.to be_completed }
    end

    context "when job is in PD state" do
      let(:job_state) { "PD" }

      it { is_expected.to be_queued }
    end

    context "when job is in unknown state" do
      let(:job_state) { "X" }

      it { is_expected.to be_undetermined }
    end

    context "when dealing with job array" do
      let(:job_hash) {
        {
          :job_id=>"123",
          :array_job_id=>"123",
          :array_task_id=>"0-3,8,10",
          :array_job_task_id=>"123_[0-3,8,10]",
          :state_compact=>"PD",
          :reason=>"JobHeldUser,Resources",
          :start_time=>"N/A",
          :submit_time=>"2017-03-31T10:09:44"
        }
      }
      let(:child_job_hash) {
        {
          :job_id=>"124",
          :array_job_id=>"123",
          :array_task_id=>"6",
          :array_job_task_id=>"123_6",
          :state_compact=>"R",
          :reason=>"None",
          :start_time=>"N/A",
          :submit_time=>"2017-03-31T10:09:44"
        }
      }

      context "and job id is array job id" do
        let(:job_id)   { "123" }
        let(:slurm)    { double(get_jobs: [child_job_hash, job_hash]) }

        it { is_expected.to be_queued }
      end

      context "and job id is formatted array job and task id" do
        let(:job_id)   { "123_6" }
        let(:slurm)    { double(get_jobs: [child_job_hash]) }

        it { is_expected.to be_running }
      end
    end

    context "when can't find job" do
      let(:slurm) { double(get_jobs: []) }

      it { is_expected.to be_completed }
    end

    context "when OodCore::Job::Adapters::Slurm::Batch::Error is raised" do
      before { expect(slurm).to receive(:get_jobs).and_raise(OodCore::Job::Adapters::Slurm::Batch::Error) }

      it "raises OodCore::JobAdapterError" do
        expect { subject }.to raise_error(OodCore::JobAdapterError)
      end
    end
  end

  describe "#hold" do
    context "when :id is not defined" do
      it "raises ArgumentError" do
        expect { adapter.hold }.to raise_error(ArgumentError)
      end
    end

    let(:job_id) { "job_id" }
    let(:slurm)  { double(hold_job: nil) }
    subject { adapter.hold(id: double(to_s: job_id)) }

    it "holds job using OodCore::Job::Adapters::Slurm::Batch" do
      subject
      expect(slurm).to have_received(:hold_job).with(job_id)
    end

    context "when OodCore::Job::Adapters::Slurm::Batch::Error is raised" do
      before { expect(slurm).to receive(:hold_job).and_raise(OodCore::Job::Adapters::Slurm::Batch::Error) }

      it "raises OodCore::JobAdapterError" do
        expect { subject }.to raise_error(OodCore::JobAdapterError)
      end
    end
  end

  describe "#release" do
    context "when :id is not defined" do
      it "raises ArgumentError" do
        expect { adapter.release }.to raise_error(ArgumentError)
      end
    end

    let(:job_id) { "job_id" }
    let(:slurm)  { double(release_job: nil) }
    subject { adapter.release(id: double(to_s: job_id)) }

    it "releases job using OodCore::Job::Adapters::Slurm::Batch" do
      subject
      expect(slurm).to have_received(:release_job).with(job_id)
    end

    context "when OodCore::Job::Adapters::Slurm::Batch::Error is raised" do
      before { expect(slurm).to receive(:release_job).and_raise(OodCore::Job::Adapters::Slurm::Batch::Error) }

      it "raises OodCore::JobAdapterError" do
        expect { subject }.to raise_error(OodCore::JobAdapterError)
      end
    end
  end

  describe "#delete" do
    context "when :id is not defined" do
      it "raises ArgumentError" do
        expect { adapter.delete }.to raise_error(ArgumentError)
      end
    end

    let(:job_id) { "job_id" }
    let(:slurm)  { double(delete_job: nil) }
    subject { adapter.delete(id: double(to_s: job_id)) }

    it "deletes job using OodCore::Job::Adapters::Slurm::Batch" do
      subject
      expect(slurm).to have_received(:delete_job).with(job_id)
    end

    context "when OodCore::Job::Adapters::Slurm::Batch::Error is raised" do
      before { expect(slurm).to receive(:delete_job).and_raise(OodCore::Job::Adapters::Slurm::Batch::Error) }

      it "raises OodCore::JobAdapterError" do
        expect { subject }.to raise_error(OodCore::JobAdapterError)
      end
    end
  end
end
