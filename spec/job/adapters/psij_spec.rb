require "spec_helper"
require "ood_core/job/adapters/psij"

describe OodCore::Job::Adapters::PSIJ do
  # Required arguments
  let(:psij) { double() }
  let(:qstat_factor) { nil }

  # Subject
  subject(:adapter) { described_class.new(psij: psij) }

  it { is_expected.to respond_to(:submit).with(1).argument.and_keywords(:after, :afterok, :afternotok, :afterany) }
  it { is_expected.to respond_to(:info_all).with(0).arguments.and_keywords(:attrs) }
  it { is_expected.to respond_to(:info_where_owner).with(1).argument.and_keywords(:attrs) }
  it { is_expected.to respond_to(:info).with(1).argument }
  it { is_expected.to respond_to(:status).with(1).argument }
  it { is_expected.to respond_to(:hold).with(1).argument }
  it { is_expected.to respond_to(:release).with(1).argument }
  it { is_expected.to respond_to(:delete).with(1).argument }
  it { is_expected.to respond_to(:directive_prefix).with(0).arguments }

  it "claims to support job arrays" do
    expect(subject.supports_job_arrays?).to be_truthy
  end

  describe ".new" do
    context "when :psij not defined" do
      subject { described_class.new }

      it "raises ArgumentError" do
        expect { subject }.to raise_error(ArgumentError)
      end
    end
  end

  describe "#submit" do
    def build_script(opts = {})
      OodCore::Job::Script.new(
        **{
          content: content
        }.merge(opts)
      )
    end

    let(:psij)  { double(submit_job_path: "job.123", executor: "slurm", queue_name:"debug") }
    let(:content) { "my batch script" }

    context "when script not defined" do
      it "raises ArgumentError" do
        expect { adapter.submit }.to raise_error(ArgumentError)
      end
    end

    subject { adapter.submit(build_script) }

    it "returns job id" do
      is_expected.to eq("job.123")
      expect(psij).to have_received(:submit_job_path).with(args: ["slurm"], chdir: nil, stdin: "{\"executable\":\"~/ood_tmp/run.sh\",\"stdout_path\":\"/home/ohmura/src/ood_core/stdout.txt\",\"stderr_path\":\"/home/ohmura/src/ood_core/stderr.txt\",\"attributes\":{},\"resources\":{\"__version\":1}}")
    end

    context "with :queue_name" do
      before { adapter.submit(build_script(queue_name: "queue")) }

      it { expect(psij).to have_received(:submit_job_path).with(args: ["slurm"], chdir: nil, stdin: "{\"executable\":\"~/ood_tmp/run.sh\",\"stdout_path\":\"/home/ohmura/src/ood_core/stdout.txt\",\"stderr_path\":\"/home/ohmura/src/ood_core/stderr.txt\",\"attributes\":{\"queue_name\":\"queue\"},\"resources\":{\"__version\":1}}") }
    end

    context "with :args" do
      before { adapter.submit(build_script(args: ["arg1", "arg2"])) }

      it { expect(psij).to have_received(:submit_job_path).with(args: ["slurm"], chdir: nil, stdin: "{\"executable\":\"~/ood_tmp/run.sh\",\"stdout_path\":\"/home/ohmura/src/ood_core/stdout.txt\",\"stderr_path\":\"/home/ohmura/src/ood_core/stderr.txt\",\"attributes\":{\"custom_attributes\":{\"arg1\":\"\",\"arg2\":\"\"}},\"resources\":{\"__version\":1}}") }
    end

    context "with :submit_as_hold" do
      context "as true" do
        before { adapter.submit(build_script(submit_as_hold: true)) }

        it { expect(psij).to have_received(:submit_job_path).with(args: ["slurm"], chdir: nil, stdin: "{\"executable\":\"~/ood_tmp/run.sh\",\"stdout_path\":\"/home/ohmura/src/ood_core/stdout.txt\",\"stderr_path\":\"/home/ohmura/src/ood_core/stderr.txt\",\"attributes\":{},\"resources\":{\"__version\":1}}") }
      end

      context "as false" do
        before { adapter.submit(build_script(submit_as_hold: false)) }

        it { expect(psij).to have_received(:submit_job_path).with(args: ["slurm"], chdir: nil, stdin: "{\"executable\":\"~/ood_tmp/run.sh\",\"stdout_path\":\"/home/ohmura/src/ood_core/stdout.txt\",\"stderr_path\":\"/home/ohmura/src/ood_core/stderr.txt\",\"attributes\":{},\"resources\":{\"__version\":1}}") }
      end
    end

    context "with :rerunnable" do
      context "as true" do
        before { adapter.submit(build_script(rerunnable: true)) }

        it { expect(psij).to have_received(:submit_job_path).with(args: ["slurm"], chdir: nil, stdin: "{\"executable\":\"~/ood_tmp/run.sh\",\"stdout_path\":\"/home/ohmura/src/ood_core/stdout.txt\",\"stderr_path\":\"/home/ohmura/src/ood_core/stderr.txt\",\"attributes\":{},\"resources\":{\"__version\":1}}") }
      end

      context "as false" do
        before { adapter.submit(build_script(rerunnable: false)) }

        it { expect(psij).to have_received(:submit_job_path).with(args: ["slurm"], chdir: nil, stdin: "{\"executable\":\"~/ood_tmp/run.sh\",\"stdout_path\":\"/home/ohmura/src/ood_core/stdout.txt\",\"stderr_path\":\"/home/ohmura/src/ood_core/stderr.txt\",\"attributes\":{},\"resources\":{\"__version\":1}}") }
      end
    end

    context "with :job_environment" do
      before { adapter.submit(build_script(job_environment: {"key" => "value"})) }

      it { expect(psij).to have_received(:submit_job_path).with(args: ["slurm"], chdir: nil, stdin: "{\"environment\":{\"key\":\"value\"},\"executable\":\"~/ood_tmp/run.sh\",\"stdout_path\":\"/home/ohmura/src/ood_core/stdout.txt\",\"stderr_path\":\"/home/ohmura/src/ood_core/stderr.txt\",\"attributes\":{},\"resources\":{\"__version\":1}}") }
    end

    context "with :job_environment and Script#copy_environment is true" do
      before { adapter.submit(build_script(copy_environment: true, job_environment: {"key" => "value"})) }
 
      it { expect(psij).to have_received(:submit_job_path).with(args: ["slurm"], chdir: nil, stdin: "{\"environment\":{\"key\":\"value\"},\"executable\":\"~/ood_tmp/run.sh\",\"stdout_path\":\"/home/ohmura/src/ood_core/stdout.txt\",\"stderr_path\":\"/home/ohmura/src/ood_core/stderr.txt\",\"inherit_environment\":true,\"attributes\":{},\"resources\":{\"__version\":1}}") }
    end

    context "with :workdir" do
      before { adapter.submit(build_script(workdir: "/path/to/workdir")) }

      it { expect(psij).to have_received(:submit_job_path).with(args: ["slurm"], chdir: Pathname.new("/path/to/workdir"), stdin: "{\"directory\":\"/path/to/workdir\",\"executable\":\"~/ood_tmp/run.sh\",\"stdout_path\":\"/home/ohmura/src/ood_core/stdout.txt\",\"stderr_path\":\"/home/ohmura/src/ood_core/stderr.txt\",\"attributes\":{},\"resources\":{\"__version\":1}}") }
    end

    context "with :email" do
      before { adapter.submit(build_script(email: ["email1", "email2"])) }

      it { expect(psij).to have_received(:submit_job_path).with(args: ["slurm"], chdir: nil, stdin: "{\"executable\":\"~/ood_tmp/run.sh\",\"stdout_path\":\"/home/ohmura/src/ood_core/stdout.txt\",\"stderr_path\":\"/home/ohmura/src/ood_core/stderr.txt\",\"attributes\":{},\"resources\":{\"__version\":1}}") }
    end

    context "with :email_on_started" do
      context "as true" do
        before { adapter.submit(build_script(email_on_started: true)) }

        it { expect(psij).to have_received(:submit_job_path).with(args: ["slurm"], chdir: nil, stdin: "{\"executable\":\"~/ood_tmp/run.sh\",\"stdout_path\":\"/home/ohmura/src/ood_core/stdout.txt\",\"stderr_path\":\"/home/ohmura/src/ood_core/stderr.txt\",\"attributes\":{},\"resources\":{\"__version\":1}}") }
      end

      context "as false" do
        before { adapter.submit(build_script(email_on_started: false)) }

        it { expect(psij).to have_received(:submit_job_path).with(args: ["slurm"], chdir: nil, stdin: "{\"executable\":\"~/ood_tmp/run.sh\",\"stdout_path\":\"/home/ohmura/src/ood_core/stdout.txt\",\"stderr_path\":\"/home/ohmura/src/ood_core/stderr.txt\",\"attributes\":{},\"resources\":{\"__version\":1}}") }
      end
    end

    context "with :email_on_terminated" do
      context "as true" do
        before { adapter.submit(build_script(email_on_terminated: true)) }

        it { expect(psij).to have_received(:submit_job_path).with(args: ["slurm"], chdir: nil, stdin: "{\"executable\":\"~/ood_tmp/run.sh\",\"stdout_path\":\"/home/ohmura/src/ood_core/stdout.txt\",\"stderr_path\":\"/home/ohmura/src/ood_core/stderr.txt\",\"attributes\":{},\"resources\":{\"__version\":1}}") }
      end

      context "as false" do
        before { adapter.submit(build_script(email_on_terminated: false)) }

        it { expect(psij).to have_received(:submit_job_path).with(args: ["slurm"], chdir: nil, stdin: "{\"executable\":\"~/ood_tmp/run.sh\",\"stdout_path\":\"/home/ohmura/src/ood_core/stdout.txt\",\"stderr_path\":\"/home/ohmura/src/ood_core/stderr.txt\",\"attributes\":{},\"resources\":{\"__version\":1}}") }
      end
    end

    context "with :email_on_started and :email_on_terminated" do
      before { adapter.submit(build_script(email_on_started: true, email_on_terminated: true)) }

      it { expect(psij).to have_received(:submit_job_path).with(args: ["slurm"], chdir: nil, stdin: "{\"executable\":\"~/ood_tmp/run.sh\",\"stdout_path\":\"/home/ohmura/src/ood_core/stdout.txt\",\"stderr_path\":\"/home/ohmura/src/ood_core/stderr.txt\",\"attributes\":{},\"resources\":{\"__version\":1}}") }
    end

    context "with :job_name" do
      before { adapter.submit(build_script(job_name: "my_job")) }

      it { expect(psij).to have_received(:submit_job_path).with(args: ["slurm"], chdir: nil, stdin: "{\"name\":\"my_job\",\"executable\":\"~/ood_tmp/run.sh\",\"stdout_path\":\"/home/ohmura/src/ood_core/stdout.txt\",\"stderr_path\":\"/home/ohmura/src/ood_core/stderr.txt\",\"attributes\":{},\"resources\":{\"__version\":1}}") }
    end

    context "with :shell_path" do
      before { adapter.submit(build_script(shell_path: "/path/to/shell")) }

      it { expect(psij).to have_received(:submit_job_path).with(args: ["slurm"], chdir: nil, stdin: "{\"executable\":\"~/ood_tmp/run.sh\",\"stdout_path\":\"/home/ohmura/src/ood_core/stdout.txt\",\"stderr_path\":\"/home/ohmura/src/ood_core/stderr.txt\",\"attributes\":{},\"resources\":{\"__version\":1}}") }
    end

    context "with :input_path" do
      before { adapter.submit(build_script(input_path: "/path/to/input")) }

      it { expect(psij).to have_received(:submit_job_path).with(args: ["slurm"], chdir: nil, stdin: "{\"executable\":\"~/ood_tmp/run.sh\",\"stdin_path\":\"/path/to/input\",\"stdout_path\":\"/home/ohmura/src/ood_core/stdout.txt\",\"stderr_path\":\"/home/ohmura/src/ood_core/stderr.txt\",\"attributes\":{},\"resources\":{\"__version\":1}}") }
    end

    context "with :output_path" do
      before { adapter.submit(build_script(output_path: "/path/to/output")) }

      it { expect(psij).to have_received(:submit_job_path).with(args: ["slurm"], chdir: nil, stdin: "{\"executable\":\"~/ood_tmp/run.sh\",\"stdout_path\":\"/path/to/output\",\"stderr_path\":\"/home/ohmura/src/ood_core/stderr.txt\",\"attributes\":{},\"resources\":{\"__version\":1}}") }
    end

    context "with :error_path" do
      before { adapter.submit(build_script(error_path: "/path/to/error")) }

      it { expect(psij).to have_received(:submit_job_path).with(args: ["slurm"], chdir: nil, stdin: "{\"executable\":\"~/ood_tmp/run.sh\",\"stdout_path\":\"/home/ohmura/src/ood_core/stdout.txt\",\"stderr_path\":\"/path/to/error\",\"attributes\":{},\"resources\":{\"__version\":1}}") }
    end

    context "with :reservation_id" do
      before { adapter.submit(build_script(reservation_id: "my_rsv")) }

      it { expect(psij).to have_received(:submit_job_path).with(args: ["slurm"], chdir: nil, stdin: "{\"executable\":\"~/ood_tmp/run.sh\",\"stdout_path\":\"/home/ohmura/src/ood_core/stdout.txt\",\"stderr_path\":\"/home/ohmura/src/ood_core/stderr.txt\",\"attributes\":{\"reservation_id\":\"my_rsv\"},\"resources\":{\"__version\":1}}") }
    end

    context "with :priority" do
      before { adapter.submit(build_script(priority: 123)) }

      it { expect(psij).to have_received(:submit_job_path).with(args: ["slurm"], chdir: nil, stdin: "{\"executable\":\"~/ood_tmp/run.sh\",\"stdout_path\":\"/home/ohmura/src/ood_core/stdout.txt\",\"stderr_path\":\"/home/ohmura/src/ood_core/stderr.txt\",\"attributes\":{},\"resources\":{\"__version\":1}}") }
    end

    context "with :start_time" do
      before { adapter.submit(build_script(start_time: Time.new(2016, 11, 8, 13, 53, 54).to_i)) }

      it { expect(psij).to have_received(:submit_job_path).with(args: ["slurm"], chdir: nil, stdin: "{\"executable\":\"~/ood_tmp/run.sh\",\"stdout_path\":\"/home/ohmura/src/ood_core/stdout.txt\",\"stderr_path\":\"/home/ohmura/src/ood_core/stderr.txt\",\"attributes\":{},\"resources\":{\"__version\":1}}") }
    end

    context "with :accounting_id" do
      before { adapter.submit(build_script(accounting_id: "my_account")) }

      it { expect(psij).to have_received(:submit_job_path).with(args: ["slurm"], chdir: nil, stdin: "{\"executable\":\"~/ood_tmp/run.sh\",\"stdout_path\":\"/home/ohmura/src/ood_core/stdout.txt\",\"stderr_path\":\"/home/ohmura/src/ood_core/stderr.txt\",\"attributes\":{\"account\":\"my_account\"},\"resources\":{\"__version\":1}}") }
    end

    context "with :wall_time" do
      before { adapter.submit(build_script(wall_time: 94534)) }

      it { expect(psij).to have_received(:submit_job_path).with(args: ["slurm"], chdir: nil, stdin: "{\"executable\":\"~/ood_tmp/run.sh\",\"stdout_path\":\"/home/ohmura/src/ood_core/stdout.txt\",\"stderr_path\":\"/home/ohmura/src/ood_core/stderr.txt\",\"attributes\":{\"duration\":94534},\"resources\":{\"__version\":1}}") }
    end

    context "with :native" do
      before { adapter.submit(build_script(native: ["--AAA", "B", "-C", "DDD", "--EEE", "--FFF"])) }

      it { expect(psij).to have_received(:submit_job_path).with(args: ["slurm"], chdir: nil, stdin: "{\"executable\":\"~/ood_tmp/run.sh\",\"stdout_path\":\"/home/ohmura/src/ood_core/stdout.txt\",\"stderr_path\":\"/home/ohmura/src/ood_core/stderr.txt\",\"attributes\":{\"custom_attributes\":{\"AAA\":\"B\",\"C\":\"DDD\",\"EEE\":\"\",\"FFF\":\"\"}},\"resources\":{\"__version\":1}}") }
    end

    %i(after afterok afternotok afterany).each do |after|
      context "and :#{after} is defined as a single job id" do
        before { adapter.submit(build_script, after => "job_id") }

        it { expect(psij).to have_received(:submit_job_path).with(args: ["slurm"], chdir: nil, stdin: "{\"executable\":\"~/ood_tmp/run.sh\",\"stdout_path\":\"/home/ohmura/src/ood_core/stdout.txt\",\"stderr_path\":\"/home/ohmura/src/ood_core/stderr.txt\",\"attributes\":{},\"resources\":{\"__version\":1}}") }
      end

      context "and :#{after} is defined as multiple job ids" do
        before { adapter.submit(build_script, after => ["job1", "job2"]) }

        it { expect(psij).to have_received(:submit_job_path).with(args: ["slurm"], chdir: nil, stdin: "{\"executable\":\"~/ood_tmp/run.sh\",\"stdout_path\":\"/home/ohmura/src/ood_core/stdout.txt\",\"stderr_path\":\"/home/ohmura/src/ood_core/stderr.txt\",\"attributes\":{},\"resources\":{\"__version\":1}}") }
      end
    end

    context "when OodCore::Job::Adapters::PSIJ::Batch::Error is raised" do
      before { expect(psij).to receive(:submit_job_path).and_raise(OodCore::Job::Adapters::PSIJ::Batch::Error) }

      it "raises OodCore::JobAdapterError" do
        expect { subject }.to raise_error(OodCore::JobAdapterError)
      end
    end
  end

  describe "#info_all" do
    let(:psij) { double(get_jobs: {}) }
    subject { adapter.info_all }

    it "returns an array of all the jobs" do
      is_expected.to eq([])
      expect(psij).to have_received(:get_jobs).with(no_args)
    end

    context "when OodCore::Job::Adapters::PSIJ::Batch::Error is raised" do
      before { expect(psij).to receive(:get_jobs).and_raise(OodCore::Job::Adapters::PSIJ::Batch::Error) }

      it "raises OodCore::JobAdapterError" do
        expect { subject }.to raise_error(OodCore::JobAdapterError)
      end
    end
  end

  describe "#info_where_owner" do
    let(:job_owner) { "job_owner" }
    let(:psij) { double(get_jobs: job_ids) }
    subject { adapter.info_where_owner(job_owner) }

    context "owner has no jobs" do
      let(:job_ids) { [] }

      it { is_expected.to eq([]) }
    end

    context "when given list of owners" do
      let(:job_ids) { [] }
      let(:job_owner) { ["job_owner_1", "job_owner_2"] }

      it "uses comma delimited owner list" do
        expect(psij).to receive(:get_jobs).with({owner: job_owner.join(",")})
        is_expected.to eq([])
      end
    end

    context "when owner has multiple jobs" do
      let(:job_ids) { [ "job_id_1", "job_id_2" ] }
      let(:psij)   { double(get_jobs: [job_hash_1, job_hash_2], executor:"slurm") }
      let(:job_hash_1) {
        {
          :native_id=>"job_id_1",
          :owner=>"#{job_owner}",
          :current_state=>"QUEUED",
        }
      }
      let(:job_hash_2) {
        {
          :native_id=>"job_id_2",
          :owner=>"#{job_owner}",
          :current_state=>"QUEUED",
        }
      }

      before do
        allow(psij).to receive(:get_jobs).with(id: "job_id_1").and_return([job_hash_1])
        allow(psij).to receive(:get_jobs).with(id: "job_id_2").and_return([job_hash_2])
      end

      it "returns list of OodCore::Job::Info objects" do
        is_expected.to eq([
          OodCore::Job::Info.new(
            :id=>"job_id_1",
            :job_owner=>job_owner,
            :submit_host=>nil,
            :status=>:queued,
            :procs=>0,
            :accounting_id=>nil,
            :queue_name=>nil,
            :wallclock_time=>nil,
            :wallclock_limit=>nil,
            :cpu_time=>nil,
            :submission_time=>nil,
            :dispatch_time=>nil,
            :allocated_nodes=>[{:name=>"", :procs=>nil, :features=>[]}],
            :job_name=>nil,
            :native=>job_hash_1
          ),
          OodCore::Job::Info.new(
            :id=>"job_id_2",
            :job_owner=>job_owner,
            :submit_host=>nil,
            :status=>:queued,
            :procs=>0,
            :accounting_id=>nil,
            :queue_name=>nil,
            :wallclock_time=>nil,
            :wallclock_limit=>nil,
            :cpu_time=>nil,
            :submission_time=>nil,
            :dispatch_time=>nil,
            :allocated_nodes=>[{:name=>"", :procs=>nil, :features=>[]}],
            :job_name=>nil,
            :native=>job_hash_2
          )
        ])
      end

      context "and when OodCore::Job::Adapters::PSIJ::Batch::Error is raised" do
        let(:psij)  { double(get_jobs: [], executor: "slurm") }
        let(:msg) { "random error" }
        before do
          expect(psij).to receive(:get_jobs).and_raise(OodCore::Job::Adapters::PSIJ::Batch::Error, msg)
        end

        it "raises OodCore::JobAdapterError" do
          expect { subject }.to raise_error(OodCore::JobAdapterError)
        end
      end
    end
  end

  describe "#info" do
    context "when id is not defined" do
      it "raises ArgumentError" do
        expect { adapter.info }.to raise_error(ArgumentError)
      end
    end

    let(:job_id)   { "job_id" }
    let(:job_hash) { {} }
    let(:psij)   { double(get_jobs: [job_hash], executor:"slurm") }
    subject { adapter.info(double(to_s: job_id)) }

    context "when job is not running" do
      let(:job_hash) {
        {
          :resourcelist=> {},
          :native_id=>job_id,
          :name=>"be_5",
          :owner=>"trzask",
          :current_state=>"QUEUED",
          :group_name=>"ludwik",
          :process_count=>14,
          :queue_name=>"oc_windfall",
          :wall_time=>nil,
          :duration=>864000,
          :cpu_time=>nil,
          :submission_time=>"Fri Jun 23 06:31:33 2017",
          :dispatch_time=>nil,
          :submit_host=>"login3.cm.cluster",
          :account=>nil
        }
      }

      it "returns correct OodCore::Job::Info object" do
        is_expected.to eq(OodCore::Job::Info.new(
          :id=>job_id,
          :status=>:queued,
          :allocated_nodes=>[
            {:name=>""},
          ],
          :submit_host=>"login3.cm.cluster",
          :job_name=>"be_5",
          :job_owner=>"trzask",
          :accounting_id=>nil,
          :procs=>14,
          :queue_name=>"oc_windfall",
          :wallclock_time=>nil,
          :wallclock_limit=>864000,
          :cpu_time=>nil,
          :submission_time=>Time.parse("Fri Jun 23 06:31:33 2017"),
          :dispatch_time=>nil,
          :native=>job_hash
        ))
      end
    end

    context "when job is running" do
      let(:job_hash) {
        {
          :resourcelist=> [
               {:name=>"i15n12", :procs=>28},
               {:name=>"i15n13", :procs=>28}
          ],
          :native_id=>job_id,
          :name=>"WT_tnc-Z08_eq",
          :owner=>"lszatkowski",
          :current_state=>"ACTIVE",
          :group_name=>"ludwik",
          :process_count=>56,
          :queue_name=>"oc_high_pri",
          :wall_time=>205742,
          :duration=>691200,
          :cpu_time=>5,
          :submission_time=>"Tue Jun 20 21:23:59 2017",
          :dispatch_time=>"Tue Jun 20 21:24:47 2017",
          :submit_host=>"login3.cm.cluster",
          :accounting_id=>nil
        }
      }

      it "returns correct OodCore::Job::Info object" do
        is_expected.to eql(OodCore::Job::Info.new(
          :id=>job_id,
          :status=>:running,
          :allocated_nodes=>[
            {:name=>"i15n12", :procs=>28},
            {:name=>"i15n13", :procs=>28}
          ],
          :submit_host=>"login3.cm.cluster",
          :job_name=>"WT_tnc-Z08_eq",
          :job_owner=>"lszatkowski",
          :accounting_id=>nil,
          :procs=>56,
          :queue_name=>"oc_high_pri",
          :wallclock_time=>205742,
          :wallclock_limit=>691200,
          :cpu_time=>5,
          :submission_time=>Time.parse("Tue Jun 20 21:23:59 2017"),
          :dispatch_time=>Time.parse("Tue Jun 20 21:24:47 2017"),
          :native=>job_hash
        ))
      end
    end

    context "when can't find job" do
      let(:psij) { double(get_jobs: []) }

      it "returns completed OodCore::Job::Info object" do
        is_expected.to eq(OodCore::Job::Info.new(id: job_id, status: :completed))
      end
    end

    context "when OodCore::Job::Adapters::PSIJ::Batch::Error is raised" do
      let(:msg) { "random error" }
      before { expect(psij).to receive(:get_jobs).and_raise(OodCore::Job::Adapters::PSIJ::Batch::Error, msg) }

      it "raises OodCore::JobAdapterError" do
        expect { subject }.to raise_error(OodCore::JobAdapterError)
      end

      context "due to invalid job id" do
        let(:msg) { "Invalid job id specified\n" }

        it "returns completed OodCore::Job::Info object" do
          is_expected.to eq(OodCore::Job::Info.new(id: job_id, status: :completed))
        end
      end
    end

    context "when user has a . in the name" do
      # exact same test as 'when job is running' context, but the user (Job_Owner)
      # is trzask.lastname@login3.cm.cluster instead of just trzask@login3.cm.cluster
      let(:job_hash) {
        {
          :resourcelist=> {},
          :native_id=>job_id,
          :name=>"be_5",
          :owner=>"trzask.lastname",
          :current_state=>"QUEUED",
          :group_name=>"ludwik",
          :process_count=>14,
          :queue_name=>"oc_windfall",
          :wallclock=>nil,
          :duration=>864000,
          :cpu_time=>nil,
          :submission_time=>"Fri Jun 23 06:31:33 2017",
          :dispatch_time=>nil,
          :submit_host=>"login3.cm.cluster",
          :accounting_id=>nil
        }
      }

      it "returns correct OodCore::Job::Info object" do
        is_expected.to eq(OodCore::Job::Info.new(
          :id=>job_id,
          :status=>:queued,
          :allocated_nodes=>[
            {:name=>""},
          ],
          :submit_host=>"login3.cm.cluster",
          :job_name=>"be_5",
          :job_owner=>"trzask.lastname",
          :accounting_id=>nil,
          :procs=>14,
          :queue_name=>"oc_windfall",
          :wallclock_time=>nil,
          :wallclock_limit=>864000,
          :cpu_time=>nil,
          :submission_time=>Time.parse("Fri Jun 23 06:31:33 2017"),
          :dispatch_time=>nil,
          :native=>job_hash
        ))
      end
    end
  end

  describe "#status" do
    context "when id is not defined" do
      it "raises ArgumentError" do
        expect { adapter.status }.to raise_error(ArgumentError)
      end
    end

    let(:job_state) { "" }
    let(:job_id)    { "job_id" }
    let(:psij)    { double(get_jobs: [job_id: job_id, current_state: job_state], executor: "slurm") }
    subject { adapter.status(double(to_s: job_id)) }

    it "request only job state from OodCore::Job::Adapters::PSIJ::Batch" do
      subject
      expect(psij).to have_received(:get_jobs).with(id: job_id)
    end

    context "when job is in NEW state" do
      let(:job_state) { "NEW" }

      it { is_expected.to be_undetermined }
    end

    context "when job is in QUEUED state" do
      let(:job_state) { "QUEUED" }

      it { is_expected.to be_queued }
    end

    context "when job is in HELD state" do
      let(:job_state) { "HELD" }

      it { is_expected.to be_queued_held }
    end

    context "when job is in ACTIVE state" do
      let(:job_state) { "ACTIVE" }

      it { is_expected.to be_running }
    end

    context "when job is in COMPLETED state" do
      let(:job_state) { "COMPLETED" }

      it { is_expected.to be_completed }
    end

    context "when OodCore::Job::Adapters::PSIJ::Batch::Error is raised" do
      let(:msg) { "random error" }
      before { expect(psij).to receive(:get_jobs).and_raise(OodCore::Job::Adapters::PSIJ::Batch::Error, msg) }

      it "raises OodCore::JobAdapterError" do
        expect { subject }.to raise_error(OodCore::JobAdapterError)
      end

      context "due to invalid job id" do
        let(:msg) { "Invalid job id specified\n" }

        it { is_expected.to be_completed }
      end
    end
  end

  describe "#hold" do
    context "when id is not defined" do
      it "raises ArgumentError" do
        expect { adapter.hold }.to raise_error(ArgumentError)
      end
    end

    let(:job_id) { "job_id" }
    let(:psij)  { double(hold_job: nil, executor: "slurm") }
    subject { adapter.hold(double(to_s: job_id)) }

    it "holds job using OodCore::Job::Adapters::PSIJ::Batch" do
      subject
      expect(psij).to have_received(:hold_job).with({:args=>["--id=job_id", "--executor=slurm"]})
    end

    context "when OodCore::Job::Adapters::PSIJ::Batch::Error is raised" do
      let(:msg) { "random error" }
      before { expect(psij).to receive(:hold_job).and_raise(OodCore::Job::Adapters::PSIJ::Batch::Error, msg) }

      it "raises OodCore::JobAdapterError" do
        expect { subject }.to raise_error(OodCore::JobAdapterError)
      end

      context "due to invalid job id" do
        let(:msg) { "Invalid job id specified\n" }

        it { is_expected.to be_nil }
      end
    end
  end

  describe "#release" do
    context "when id is not defined" do
      it "raises ArgumentError" do
        expect { adapter.release }.to raise_error(ArgumentError)
      end
    end

    let(:job_id) { "job_id" }
    let(:psij)  { double(release_job: nil, executor:"slurm") }
    subject { adapter.release(double(to_s: job_id)) }

    it "releases job using OodCore::Job::Adapters::PSIJ::Batch" do
      subject
      expect(psij).to have_received(:release_job).with({:args=>["--id=job_id", "--executor=slurm"]})
    end

    context "when OodCore::Job::Adapters::PSIJ::Batch::Error is raised" do
      let(:msg) { "random error" }
      before { expect(psij).to receive(:release_job).and_raise(OodCore::Job::Adapters::PSIJ::Batch::Error, msg) }

      it "raises OodCore::JobAdapterError" do
        expect { subject }.to raise_error(OodCore::JobAdapterError)
      end

      context "due to invalid job id" do
        let(:msg) { "Invalid job id specified\n" }

        it { is_expected.to be_nil }
      end
    end
  end

  describe "#delete" do
    context "when id is not defined" do
      it "raises ArgumentError" do
        expect { adapter.delete }.to raise_error(ArgumentError)
      end
    end

    let(:job_id) { "job_id" }
    let(:psij) { double(delete_job: nil, executor: "slurm") }
    subject { adapter.delete(double(to_s: job_id)) }

    it "deletes job using OodCore::Job::Adapters::PSIJ::Batch" do
      subject
      expect(psij).to have_received(:delete_job).with({:args=>["--id=job_id", "--executor=slurm"]})
    end

    context "when OodCore::Job::Adapters::PSIJ::Batch::Error is raised" do
      let(:msg) { "random error" }
      before { expect(psij).to receive(:delete_job).and_raise(OodCore::Job::Adapters::PSIJ::Batch::Error, msg) }

      it "raises OodCore::JobAdapterError" do
        expect { subject }.to raise_error(OodCore::JobAdapterError)
      end

      context "due to invalid job id" do
        let(:msg) { "Invalid job id specified\n" }

        it { is_expected.to be_nil }
      end
    end
  end

  describe "customizing bin paths" do
    let(:script) { OodCore::Job::Script.new(content: "echo 'hi'") }

    context "when calling with no config" do
      it "uses correct command" do
        batch = OodCore::Job::Adapters::PSIJ::Batch.new(cluster: "owens.osc.edu", conf: nil, bin_overrides: {})
        allow(Open3).to receive(:capture3).and_return(["job.123", "", double("success?" => true)])

        OodCore::Job::Adapters::PSIJ.new(psij: batch).submit script
        expect(Open3).to have_received(:capture3).with(anything, "python3", any_args)
      end
    end

    context "when calling with normal config" do
      it "uses the correct command" do
        batch = OodCore::Job::Adapters::PSIJ::Batch.new(cluster: "owens.osc.edu", conf: "/etc/slurm.conf", bin_overrides: {})
        allow(Open3).to receive(:capture3).and_return(["job.123", "", double("success?" => true)])

        OodCore::Job::Adapters::PSIJ.new(psij: batch).submit script
        expect(Open3).to have_received(:capture3).with(anything, "python3", any_args)
      end
    end

    context "when calling with overrides" do
      it "uses the correct command" do
        batch = OodCore::Job::Adapters::PSIJ::Batch.new(cluster: "owens.osc.edu", conf: "/opt/psij", bin_overrides: {"python3" => "not_python"})
        allow(Open3).to receive(:capture3).and_return(["job.123", "", double("success?" => true)])

        OodCore::Job::Adapters::PSIJ.new(psij: batch).submit script
        expect(Open3).to have_received(:capture3).with(anything, "not_python", any_args)
      end
    end
  end

  describe "setting submit_host" do 
    let(:script) { OodCore::Job::Script.new(content: "echo 'hi'") }

    context "when calling withoug submit_host" do
      it "uses the correct command" do
        batch = OodCore::Job::Adapters::PSIJ::Batch.new(cluster: "owens.osc.edu", conf: nil, bin_overrides: {}, submit_host: "")
        allow(Open3).to receive(:capture3).and_return(["job.123", "", double("success?" => true)])

        OodCore::Job::Adapters::PSIJ.new(psij: batch).submit script
        expect(Open3).to have_received(:capture3).with(anything, "python3", any_args)
      end
    end

    context "when calling with submit_host & strict_host_checking not specified" do 
      it "uses ssh wrapper & host checking defaults to yes" do
        batch = OodCore::Job::Adapters::PSIJ::Batch.new(cluster: "owens.osc.edu", conf: nil, bin_overrides: {}, submit_host: "owens.osc.edu")
        allow(Open3).to receive(:capture3).and_return(["job.123", "", double("success?" => true)])

        OodCore::Job::Adapters::PSIJ.new(psij: batch).submit script
        expect(Open3).to have_received(:capture3).with(anything,'ssh', '-p', '22', '-o', 'BatchMode=yes', '-o', 'UserKnownHostsFile=/dev/null', '-o', 'StrictHostKeyChecking=yes', 'owens.osc.edu', 'python3', any_args)
      end
    end

    context "when strict_host_checking = 'no' && submit_host specified" do
      it "defaults host checking to no" do
        batch = OodCore::Job::Adapters::PSIJ::Batch.new(cluster: "owens.osc.edu", conf: nil, bin_overrides: {}, submit_host: "owens.osc.edu", strict_host_checking: false)
        allow(Open3).to receive(:capture3).and_return(["job.123", "", double("success?" => true)])

        OodCore::Job::Adapters::PSIJ.new(psij: batch).submit script
        expect(Open3).to have_received(:capture3).with(anything,'ssh', '-p', '22', '-o', 'BatchMode=yes', '-o', 'UserKnownHostsFile=/dev/null', '-o', 'StrictHostKeyChecking=no', 'owens.osc.edu', 'python3', any_args)
      end
    end
  end

  describe "#directive_prefix" do
      context "when called" do
        it "does not raise an error" do
          expect { adapter.directive_prefix }.not_to raise_error
        end
      end
    end
end
