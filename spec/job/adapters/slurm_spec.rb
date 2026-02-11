require "spec_helper"
require "ood_core/job/adapters/slurm"

describe OodCore::Job::Adapters::Slurm do
  # Required arguments
  let(:slurm) { double() }

  # Subject
  subject(:adapter) { described_class.new(slurm: slurm) }

  it { is_expected.to respond_to(:submit).with(1).argument.and_keywords(:after, :afterok, :afternotok, :afterany) }
  it { is_expected.to respond_to(:info_all).with(0).arguments.and_keywords(:attrs) }
  it { is_expected.to respond_to(:info_historic).with(0).arguments.and_keywords(:opts) }
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
        **{
          content: content
        }.merge(opts)
      )
    end

    let(:slurm) { double(submit_string: "job.123") }
    let(:content) { "my batch script" }

    context "when script not defined" do
      it "raises ArgumentError" do
        expect { adapter.submit }.to raise_error(ArgumentError)
      end
    end

    subject { adapter.submit(build_script) }

    it "returns job id" do
      is_expected.to eq("job.123")
      expect(slurm).to have_received(:submit_string).with(content, args: ["--export", "NONE"], env: {})
    end

    context "with :queue_name" do
      before { adapter.submit(build_script(queue_name: "queue")) }

      it { expect(slurm).to have_received(:submit_string).with(content, args: ["-p", "queue", "--export", "NONE"], env: {}) }
    end

    context "with :args" do
      before { adapter.submit(build_script(args: ["arg1", "arg2"])) }

      it { expect(slurm).to have_received(:submit_string).with(content, args: ["--export", "NONE"], env: {}) }
    end

    context "with :submit_as_hold" do
      context "as true" do
        before { adapter.submit(build_script(submit_as_hold: true)) }

        it { expect(slurm).to have_received(:submit_string).with(content, args: ["-H", "--export", "NONE"], env: {}) }
      end

      context "as false" do
        before { adapter.submit(build_script(submit_as_hold: false)) }

        it { expect(slurm).to have_received(:submit_string).with(content, args: ["--export", "NONE"], env: {}) }
      end
    end

    context "with :rerunnable" do
      context "as true" do
        before { adapter.submit(build_script(rerunnable: true)) }

        it { expect(slurm).to have_received(:submit_string).with(content, args: ["--requeue", "--export", "NONE"], env: {}) }
      end

      context "as false" do
        before { adapter.submit(build_script(rerunnable: false)) }

        it { expect(slurm).to have_received(:submit_string).with(content, args: ["--no-requeue", "--export", "NONE"], env: {}) }
      end
    end

    context "with :job_environment" do
      before { adapter.submit(build_script(job_environment: {"key" => "value"})) }

      it { expect(slurm).to have_received(:submit_string).with(content, args: ["--export", "key"], env: {"key" => "value"}) }
    end

    context "with :job_environment where copy_environment is true" do
      before { adapter.submit(build_script(copy_environment: true, job_environment: {"key" => "value"})) }

      it { expect(slurm).to have_received(:submit_string).with(content, args: ["--export", "ALL,key"], env: {"key" => "value"}) }
    end

    context "with :copy_environment and no :job_environment" do
      before { adapter.submit(build_script(copy_environment: true)) }

      it { expect(slurm).to have_received(:submit_string).with(content, args: ["--export", "ALL"], env: {}) }
    end

    context "with :workdir" do
      before { adapter.submit(build_script(workdir: "/path/to/workdir")) }

      it { expect(slurm).to have_received(:submit_string).with(content, args: ["-D", "/path/to/workdir", "--export", "NONE"], env: {}) }
    end

    context "with :email" do
      before { adapter.submit(build_script(email: ["email1", "email2"])) }

      it { expect(slurm).to have_received(:submit_string).with(content, args: ["--mail-user", "email1,email2", "--export", "NONE"], env: {}) }
    end

    context "with :email_on_started" do
      context "as true" do
        before { adapter.submit(build_script(email_on_started: true)) }

        it { expect(slurm).to have_received(:submit_string).with(content, args: ["--mail-type", "BEGIN", "--export", "NONE"], env: {}) }
      end

      context "as false" do
        before { adapter.submit(build_script(email_on_started: false)) }

        it { expect(slurm).to have_received(:submit_string).with(content, args: ["--export", "NONE"], env: {}) }
      end
    end

    context "with :email_on_terminated" do
      context "as true" do
        before { adapter.submit(build_script(email_on_terminated: true)) }

        it { expect(slurm).to have_received(:submit_string).with(content, args: ["--mail-type", "END", "--export", "NONE"], env: {}) }
      end

      context "as false" do
        before { adapter.submit(build_script(email_on_terminated: false)) }

        it { expect(slurm).to have_received(:submit_string).with(content, args: ["--export", "NONE"], env: {}) }
      end
    end

    context "with :email_on_started and :email_on_terminated" do
      before { adapter.submit(build_script(email_on_started: true, email_on_terminated: true)) }

      it { expect(slurm).to have_received(:submit_string).with(content, args: ["--mail-type", "ALL", "--export", "NONE"], env: {}) }
    end

    context "with :job_name" do
      before { adapter.submit(build_script(job_name: "my_job")) }

      it { expect(slurm).to have_received(:submit_string).with(content, args: ["-J", "my_job", "--export", "NONE"], env: {}) }
    end

    context "with :shell_path" do
      before { adapter.submit(build_script(shell_path: "/path/to/shell")) }

      it { expect(slurm).to have_received(:submit_string).with("#!/path/to/shell\n#{content}", args: ["--export", "NONE"], env: {}) }
    end

    context "with :input_path" do
      before { adapter.submit(build_script(input_path: "/path/to/input")) }

      it { expect(slurm).to have_received(:submit_string).with(content, args: ["-i", Pathname.new("/path/to/input"), "--export", "NONE"], env: {}) }
    end

    context "with :output_path" do
      before { adapter.submit(build_script(output_path: "/path/to/output")) }

      it { expect(slurm).to have_received(:submit_string).with(content, args: ["-o", Pathname.new("/path/to/output"), "--export", "NONE"], env: {}) }
    end

    context "with :error_path" do
      before { adapter.submit(build_script(error_path: "/path/to/error")) }

      it { expect(slurm).to have_received(:submit_string).with(content, args: ["-e", Pathname.new("/path/to/error"), "--export", "NONE"], env: {}) }
    end

    context "with :reservation_id" do
      before { adapter.submit(build_script(reservation_id: "my_rsv")) }

      it { expect(slurm).to have_received(:submit_string).with(content, args: ["--reservation", "my_rsv", "--export", "NONE"], env: {}) }
    end

    context "with :priority" do
      before { adapter.submit(build_script(priority: 123)) }

      it { expect(slurm).to have_received(:submit_string).with(content, args: ["--priority", 123, "--export", "NONE"], env: {}) }
    end

    context "with :start_time" do
      before { adapter.submit(build_script(start_time: Time.new(2016, 11, 8, 13, 53, 54).to_i)) }

      it { expect(slurm).to have_received(:submit_string).with(content, args: ["--begin", "2016-11-08T13:53:54", "--export", "NONE"], env: {}) }
    end

    context "with :accounting_id" do
      before { adapter.submit(build_script(accounting_id: "my_account")) }

      it { expect(slurm).to have_received(:submit_string).with(content, args: ["-A", "my_account", "--export", "NONE"], env: {}) }
    end

    context "with :wall_time" do
      before { adapter.submit(build_script(wall_time: 94534)) }

      it { expect(slurm).to have_received(:submit_string).with(content, args: ["-t", "26:15:34", "--export", "NONE"], env: {}) }
    end

    context "with :qos" do
      before { adapter.submit(build_script(qos: "test")) }

      it { expect(slurm).to have_received(:submit_string).with(content, args: ["--qos", "test", "--export", "NONE"], env: {}) }
    end

    context "with :gpus_per_node" do
      before { adapter.submit(build_script(gpus_per_node: 1)) }

      it { expect(slurm).to have_received(:submit_string).with(content, args: ["--gpus-per-node", 1, "--export", "NONE"], env: {}) }
    end

    context "with :native" do
      before { adapter.submit(build_script(native: ["A", "B", "C"])) }

      it { expect(slurm).to have_received(:submit_string).with(content, args: ["--export", "NONE", "A", "B", "C"], env: {}) }
    end

    context "with :qos" do
      before { adapter.submit(build_script(qos: 'high')) }

      it { expect(slurm).to have_received(:submit_string).with(content, args:["--qos", "high", "--export", "NONE"], env: {})}
    end

    %i(after afterok afternotok afterany).each do |after|
      context "and :#{after} is defined as a single job id" do
        before { adapter.submit(build_script, after => "job_id") }

        it { expect(slurm).to have_received(:submit_string).with(content, args: ["-d", "#{after}:job_id", "--export", "NONE"], env: {}) }
      end

      context "and :#{after} is defined as multiple job ids" do
        before { adapter.submit(build_script, after => ["job1", "job2"]) }

        it { expect(slurm).to have_received(:submit_string).with(content, args: ["-d", "#{after}:job1:job2", "--export", "NONE"], env: {}) }
      end
    end

    context "when OodCore::Job::Adapters::Slurm::Batch::Error is raised" do
      before { expect(slurm).to receive(:submit_string).and_raise(OodCore::Job::Adapters::Slurm::Batch::Error) }

      it "raises OodCore::JobAdapterError" do
        expect { subject }.to raise_error(OodCore::JobAdapterError)
      end
    end
  end

  describe "#info_all" do
    context "when no jobs" do
      it "returns an array of all the jobs" do
        adapter = OodCore::Job::Adapters::Slurm.new(slurm: double(get_jobs: []))
        expect(adapter.info_all).to eq([])
      end
    end

    context "when OodCore::Job::Adapters::Slurm::Batch::Error is raised" do
      it "raises OodCore::JobAdapterError" do
        slurm = double(get_jobs: [])
        expect(slurm).to receive(:get_jobs).and_raise(OodCore::Job::Adapters::Slurm::Batch::Error)
        adapter = OodCore::Job::Adapters::Slurm.new(slurm: slurm)

        expect { adapter.info_all }.to raise_error(OodCore::JobAdapterError)
      end
    end

    context "when jobs" do
      it "returns an array of all the jobs" do
        batch = OodCore::Job::Adapters::Slurm::Batch.new(
                  conf: "/etc/slurm/conf/",
                  bin: nil,
                  bin_overrides: { "squeue" => "spec/fixtures/scripts/squeue.rb"}
        )
        jobs = OodCore::Job::Adapters::Slurm.new(slurm: batch).info_all

        expect(jobs.count).to eq(2)

        j1 = jobs.first
        expect(j1.id).to eq("5096321")
        expect(j1.accounting_id).to eq("oscstaff")
        expect(j1.job_name).to eq("Interact")
        expect(j1.queue_name).to eq("RM-small")
        expect(j1.native[:work_dir]).to eq("/home/efranz")
        expect(j1.status).to eq("completed")
        expect(j1.status).to eq(OodCore::Job::Status.new(state: :completed))
        expect(j1.status.to_s).to eq("completed")
        expect(j1.gpus).to eq(1)
        expect(j1.gpu?).to eq(true)

        j2 = jobs.last
        expect(j2.id).to eq("4320602")
        expect(j2.accounting_id).to eq("ct4s8dp")
        expect(j2.job_name).to eq("LES-data-init")
        expect(j2.queue_name).to eq("RM")
        expect(j2.native[:work_dir]).to eq("/scratch/ct4s8dp/kyu2/LES-data")
        expect(j2.status).to eq("queued")
        expect(j2.status).to eq(OodCore::Job::Status.new(state: :queued))
        expect(j2.status.to_s).to eq("queued")
        expect(j2.gpus).to eq(0)
        expect(j2.gpu?).to eq(false)
      end
    end

    context "when in a multi-cluster environment" do
      it "returns an array of all the jobs" do
        batch = OodCore::Job::Adapters::Slurm::Batch.new(
                  conf: "/etc/slurm/conf/",
                  bin: nil,
                  bin_overrides: { "squeue" => "spec/fixtures/scripts/squeue_with_cluster_header.rb"},
                  cluster: 'slurm_cluster_two'
        )
        jobs = OodCore::Job::Adapters::Slurm.new(slurm: batch).info_all

        expect(jobs.count).to eq(2)

        j1 = jobs.first
        expect(j1.id).to eq("5096321")
        expect(j1.accounting_id).to eq("oscstaff")
        expect(j1.job_name).to eq("Interact")
        expect(j1.queue_name).to eq("RM-small")
        expect(j1.native[:work_dir]).to eq("/home/efranz")
        expect(j1.status).to eq("completed")
        expect(j1.status).to eq(OodCore::Job::Status.new(state: :completed))
        expect(j1.status.to_s).to eq("completed")

        j2 = jobs.last
        expect(j2.id).to eq("4320602")
        expect(j2.accounting_id).to eq("ct4s8dp")
        expect(j2.job_name).to eq("LES-data-init")
        expect(j2.queue_name).to eq("RM")
        expect(j2.native[:work_dir]).to eq("/scratch/ct4s8dp/kyu2/LES-data")
        expect(j2.status).to eq("queued")
        expect(j2.status).to eq(OodCore::Job::Status.new(state: :queued))
        expect(j2.status.to_s).to eq("queued")
      end
    end
  end

  describe "#info_historic" do
    context "when no jobs" do
      it "returns an array of all the jobs" do
        adapter = OodCore::Job::Adapters::Slurm.new(slurm: double(sacct_info: []))
        expect(adapter.info_historic).to eq([])
      end
    end

    context "when jobs" do
      it "returns an array of all the jobs" do
        batch = OodCore::Job::Adapters::Slurm::Batch.new(
          conf: "/etc/slurm/conf/",
          bin: nil,
          bin_overrides: { "sacct" => "spec/fixtures/scripts/sacct.rb"}
        )
        jobs = OodCore::Job::Adapters::Slurm.new(slurm: batch).info_historic

        expect(jobs.count).to eq(3)

        j1 = jobs.first
        expect(j1.id).to eq("20251")
        expect(j1.job_name).to eq("RDesktop")
        expect(j1.queue_name).to eq("normal")
        expect(j1.status).to eq("queued")
        expect(j1.status).to eq(OodCore::Job::Status.new(state: :queued))
        expect(j1.status.to_s).to eq("queued")
        expect(j1.gpus).to eq(1)
        expect(j1.gpu?).to eq(true)

        j2 = jobs[1]
        expect(j2.id).to eq("20252")
        expect(j2.job_name).to eq("RStudio")
        expect(j2.queue_name).to eq("normal")
        expect(j2.status).to eq("running")
        expect(j2.status).to eq(OodCore::Job::Status.new(state: :running))
        expect(j2.status.to_s).to eq("running")
        expect(j2.gpus).to eq(0)
        expect(j2.gpu?).to eq(false)

        j3 = jobs.last
        expect(j3.id).to eq("5963565")
        expect(j3.job_name).to eq("RStudio")
        expect(j3.queue_name).to eq("interactive")
        expect(j3.status).to eq("completed")
        expect(j3.status).to eq(OodCore::Job::Status.new(state: :completed))
        expect(j3.status.to_s).to eq("completed")
      end
    end
  end

  describe "#info" do
    def job_info(opts = {})
      OodCore::Job::Info.new(
        **job_info_hash.merge(opts)
      )
    end

    let(:job_id)   { "job_id" }
    let(:job_hash) { {} }
    let(:slurm)    { double(get_jobs: [job_hash]) }
    subject { adapter.info(double(to_s: job_id)) }

    context "when id is not defined" do
      it "raises ArgumentError" do
        expect { adapter.info }.to raise_error(ArgumentError)
      end
    end

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
          :scheduled_nodes=>scheduled_nodes,
          :sockets_cores_threads=>"*:*:*",
          :work_dir=>"/uufs/chpc.utah.edu/common/home/u0549046/king3/run/happel20"
        }
      }

      let(:job_info_hash) {
        {
          :id=>job_id,
          :status=>:queued,
          :allocated_nodes=>[
            {:name=>nil}
          ],
          :submit_host=>nil,
          :job_name=>"jobname.err",
          :job_owner=>"u0549046",
          :accounting_id=>"mah-kp",
          :procs=>24,
          :queue_name=>"mah-kp",
          :wallclock_time=>0,
          :wallclock_limit=>259200,
          :cpu_time=>nil,
          :submission_time=>Time.parse("2017-03-30T13:28:01"),
          :dispatch_time=>Time.parse("2017-04-01T22:13:03"),
          :native=>job_hash
        }
      }

      context "and no scheduled nodes provided" do
        let(:scheduled_nodes) { "(null)" }

        it "returns correct OodCore::Job::Info object" do
          is_expected.to eq(job_info)
        end
      end

      context "and there are scheduled nodes provided" do
        let(:scheduled_nodes) { "kp[002,009-011]" }

        it "returns correct OodCore::Job::Info object" do
          is_expected.to eq(job_info(
            allocated_nodes: [
              {name: "kp002"},
              {name: "kp009"},
              {name: "kp010"},
              {name: "kp011"}
            ]
          ))
        end
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
          :node_list=>"kp[002,006,026-029,158-159,162-164,197-199],ky123,kz[006,009-011]",
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

      let(:job_info_hash) {
        {
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
            {:name=>"kp199", :procs=>nil},
            {:name=>"ky123", :procs=>nil},
            {:name=>"kz006", :procs=>nil},
            {:name=>"kz009", :procs=>nil},
            {:name=>"kz010", :procs=>nil},
            {:name=>"kz011", :procs=>nil}
          ],
          :submit_host=>nil,
          :job_name=>"big_CB7CB_330Knptall_modTD",
          :job_owner=>"u0135669",
          :accounting_id=>"hooper",
          :procs=>256,
          :queue_name=>"kingspeak",
          :wallclock_time=>80135,
          :wallclock_limit=>259200,
          :cpu_time=>nil,
          :submission_time=>Time.parse("2017-03-29T13:51:05"),
          :dispatch_time=>Time.parse("2017-03-30T10:21:54"),
          :native=>job_hash
        }
      }

      it "returns correct OodCore::Job::Info object" do
        is_expected.to eql(job_info)
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
          :submit_time=>"2017-03-31T10:09:44",
          :time_limit=>"30:00"
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
          :submit_time=>"2017-03-31T10:09:44",
          :time_limit=>"10:00:00"
        }
      }

      context "and when child tasks are returned" do
        let(:slurm)    { double(get_jobs: [child_job_hash, job_hash]) }

        let(:aggregate_job_info) {
          OodCore::Job::Info.new(
            id: "123",
            status: :running,
            allocated_nodes: [],
            submit_host: nil,
            job_name: nil,
            job_owner: nil,
            accounting_id: nil,
            procs: nil,
            queue_name: nil,
            wallclock_time: 0,
            wallclock_limit: 1800,
            cpu_time: nil,
            submission_time: Time.parse("2017-03-31T10:09:44"),
            tasks: [
              {:id => 124, :status => :running},
              {:id => 123, :status => :queued}
            ],
            dispatch_time: nil,
            native: job_hash
          )
        }

        it "creates the proper aggregate job info" do
          expect( adapter.info('123') ).to eq(aggregate_job_info)
        end
      end

      context "and job id is formatted array job and task id" do
        let(:job_id)   { "123_6" }
        let(:slurm)    { double(get_jobs: [child_job_hash]) }

        let(:job_info_hash) {
          {
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
            :wallclock_limit=>36000,
            :cpu_time=>nil,
            :submission_time=>Time.parse("2017-03-31T10:09:44"),
            :dispatch_time=>nil,
            :native=>child_job_hash
          }
        }

        it "returns correct OodCore::Job::Info object" do
          is_expected.to eq(job_info)
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
      let(:msg) { "random error" }
      before { expect(slurm).to receive(:get_jobs).and_raise(OodCore::Job::Adapters::Slurm::Batch::Error, msg) }

      it "raises OodCore::JobAdapterError" do
        expect { subject }.to raise_error(OodCore::JobAdapterError)
      end

      context "due to invalid job id" do
        let(:msg) { "slurm_load_jobs error: Invalid job id specified\n" }

        it "returns completed OodCore::Job::Info object" do
          is_expected.to eq(OodCore::Job::Info.new(id: job_id, status: :completed))
        end
      end
    end

    context "when account is '(null)'" do
      let(:job_hash) {
        {
          :account=>"(null)",
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
          :node_list=>"ky123",
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

      let(:job_info_hash) {
        {
          :id=>job_id,
          :status=>:running,
          :allocated_nodes=>[
            {:name=>"ky123", :procs=>nil}
          ],
          :submit_host=>nil,
          :job_name=>"big_CB7CB_330Knptall_modTD",
          :job_owner=>"u0135669",
          :accounting_id=>nil,
          :procs=>256,
          :queue_name=>"kingspeak",
          :wallclock_time=>80135,
          :wallclock_limit=>259200,
          :cpu_time=>nil,
          :submission_time=>Time.parse("2017-03-29T13:51:05"),
          :dispatch_time=>Time.parse("2017-03-30T10:21:54"),
          :native=>job_hash
        }
      }

      it "returns correct OodCore::Job::Info object" do
        is_expected.to eql(job_info)
      end
    end

    context "when job name has non utf8 characters" do

      let(:squeue_args) {[
        "squeue",
        "--all",
        "--states=all",
        "--noconvert",
        "-o",
        "\u001E%a\u001F%A\u001F%B\u001F%c\u001F%C\u001F%d\u001F%D\u001F%e\u001F%E\u001F%f\u001F%F\u001F%g\u001F%G\u001F%h\u001F%H\u001F%i\u001F%I\u001F%j\u001F%J\u001F%k\u001F%K\u001F%l\u001F%L\u001F%m\u001F%M\u001F%n\u001F%N\u001F%o\u001F%O\u001F%q\u001F%P\u001F%Q\u001F%r\u001F%S\u001F%t\u001F%T\u001F%u\u001F%U\u001F%v\u001F%V\u001F%w\u001F%W\u001F%x\u001F%X\u001F%y\u001F%Y\u001F%z\u001F%Z\u001F%b",
        "-j",
        "123"
      ]}

      it "correctly handles non utf8 characters" do
        stdout = File.read('spec/fixtures/output/slurm/non_utf8_job_name.txt')
        stdout.force_encoding(Encoding::ASCII)
        allow(Open3).to receive(:capture3).with({}, *squeue_args, stdin_data: "").and_return([stdout, '', double("success?" => true)])
        job = OodCore::Job::Factory.build_slurm({}).info('123')
        expect(job.job_owner).to eq('annie.oakley')
        expect(job.job_name).to eq('��� non-utf8')
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
    let(:slurm)     { double(get_jobs: [job_id: job_id, array_job_task_id: job_id, state_compact: job_state]) }
    subject { adapter.status(double(to_s: job_id)) }

    it "request only job state from OodCore::Job::Adapters::Slurm::Batch" do
      subject
      expect(slurm).to have_received(:get_jobs).with(id: job_id, attrs: [:job_id, :array_job_task_id, :state_compact])
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

      it { is_expected.to be_suspended }
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
      let(:msg) { "random error" }
      before { expect(slurm).to receive(:get_jobs).and_raise(OodCore::Job::Adapters::Slurm::Batch::Error, msg) }

      it "raises OodCore::JobAdapterError" do
        expect { subject }.to raise_error(OodCore::JobAdapterError)
      end

      context "due to invalid job id" do
        let(:msg) { "slurm_load_jobs error: Invalid job id specified\n" }

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
    let(:slurm)  { double(hold_job: nil) }
    subject { adapter.hold(double(to_s: job_id)) }

    it "holds job using OodCore::Job::Adapters::Slurm::Batch" do
      subject
      expect(slurm).to have_received(:hold_job).with(job_id)
    end

    context "when OodCore::Job::Adapters::Slurm::Batch::Error is raised" do
      let(:msg) { "random error" }
      before { expect(slurm).to receive(:hold_job).and_raise(OodCore::Job::Adapters::Slurm::Batch::Error, msg) }

      it "raises OodCore::JobAdapterError" do
        expect { subject }.to raise_error(OodCore::JobAdapterError)
      end

      context "due to invalid job id" do
        let(:msg) { "slurm_hold_job error: Invalid job id specified\n" }

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
    let(:slurm)  { double(release_job: nil) }
    subject { adapter.release(double(to_s: job_id)) }

    it "releases job using OodCore::Job::Adapters::Slurm::Batch" do
      subject
      expect(slurm).to have_received(:release_job).with(job_id)
    end

    context "when OodCore::Job::Adapters::Slurm::Batch::Error is raised" do
      let(:msg) { "random error" }
      before { expect(slurm).to receive(:release_job).and_raise(OodCore::Job::Adapters::Slurm::Batch::Error, msg) }

      it "raises OodCore::JobAdapterError" do
        expect { subject }.to raise_error(OodCore::JobAdapterError)
      end

      context "due to invalid job id" do
        let(:msg) { "slurm_release_job error: Invalid job id specified\n" }

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
    let(:slurm)  { double(delete_job: nil) }
    subject { adapter.delete(double(to_s: job_id)) }

    it "deletes job using OodCore::Job::Adapters::Slurm::Batch" do
      subject
      expect(slurm).to have_received(:delete_job).with(job_id)
    end

    context "when OodCore::Job::Adapters::Slurm::Batch::Error is raised" do
      let(:msg) { "random error" }
      before { expect(slurm).to receive(:delete_job).and_raise(OodCore::Job::Adapters::Slurm::Batch::Error, msg) }

      it "raises OodCore::JobAdapterError" do
        expect { subject }.to raise_error(OodCore::JobAdapterError)
      end

      context "due to invalid job id" do
        let(:msg) { "slurm_delete_job error: Invalid job id specified\n" }

        it { is_expected.to be_nil }
      end
    end
  end

  describe "OodCore::Job::Adapters::Slurm::Batch" do
    subject(:batch) { OodCore::Job::Adapters::Slurm::Batch.new }

    it "has its fields in the correct order to work with Slurm 18" do
      expect(batch.send(:all_squeue_fields).values.last).to eq("%b")
    end

    describe "#squeue_fields" do
      # 1. nil arg: all attrs
      # 2. [] arg: only required attrs
      # 3. [:something] => include minimum required i.e. [:id, :status] and specified attr (either Info or slurm specific attr name)
      it "returns all fields for nil attrs" do
        expect(batch.squeue_fields(nil)).to eq(batch.all_squeue_fields)
      end

      it "ensures id and status are included" do
        expect(batch.squeue_fields([:time_used]).keys.sort).to eq([:job_id,  :state_compact, :time_used])
      end

      it "returns only required fields for an empty attrs array" do
        expect(batch.squeue_fields([]).keys).to eq([:job_id,  :state_compact])
        expect(batch.squeue_fields([:job_id]).keys.sort).to eq([:job_id,  :state_compact])
        expect(batch.squeue_fields([:state_compact]).keys.sort).to eq([:job_id,  :state_compact])
      end

      it "replaces Info attr with squeue attr reqeusts" do
        expect(batch.squeue_fields([:id, :status, :job_name, :queue_name]).keys.sort).to eq([:job_id,  :job_name, :partition, :state_compact])
      end

      it "handles allocated_nodes" do
        expect(batch.squeue_fields([:allocated_nodes]).keys.sort).to include(:node_list, :scheduled_nodes)
        # expect(batch.squeue_fields([:allocated_nodes]).keys.sort).to eq([:job_id, :node_list, :scheduled_nodes :state_compact])
      end

      it "uses the record separator character once at the start of the format string" do
        expect(
          batch.squeue_args(options: batch.squeue_fields(nil).values).one? do |arg|
            arg.start_with?(OodCore::Job::Adapters::Slurm::Batch::RECORD_SEPARATOR)
          end
        ).to be_truthy
      end

      # TODO: what Active Jobs would query
      # it "handles ActiveJobs query" do
      #   expect(batch.squeue_fields([:accounting_id, :allocated_nodes, :job_name, :job_owner, :queue_name, :wallclock_time ]).keys.sort).to eq(
      #     [:account, :job_id, :job_name, :node_list, :partition, :scheduled_nodes, :state_compact, :time_used, :user])
      # end
    end

    describe "#get_jobs" do
      let(:squeue_args) {[
        "squeue",
        "--all",
        "--states=all",
        "--noconvert",
        "-o",
        "\u001E%a\u001F%A\u001F%B\u001F%c\u001F%C\u001F%d\u001F%D\u001F%e\u001F%E\u001F%f\u001F%F\u001F%g\u001F%G\u001F%h\u001F%H\u001F%i\u001F%I\u001F%j\u001F%J\u001F%k\u001F%K\u001F%l\u001F%L\u001F%m\u001F%M\u001F%n\u001F%N\u001F%o\u001F%O\u001F%q\u001F%P\u001F%Q\u001F%r\u001F%S\u001F%t\u001F%T\u001F%u\u001F%U\u001F%v\u001F%V\u001F%w\u001F%W\u001F%x\u001F%X\u001F%y\u001F%Y\u001F%z\u001F%Z\u001F%b",
        "-j",
        "123"
      ]}

      it "handles Slurm socket timeouts" do
        slurm_stderr = "slurm_load_jobs error: Socket timed out on send/recv operation"
        slurm_stdout = "CLUSTER: saturn"

        allow(Open3).to receive(:capture3).with({}, *squeue_args, stdin_data: "").and_return([slurm_stdout, slurm_stderr, double("success?" => true)])
        expect(batch.get_jobs(id: '123')).to eq([{ id: '123', state: 'undetermined'}])
      end

      it "still propogates non-zero exitting errors" do
        slurm_stderr = "Some unhandled error"
        slurm_stdout = ""

        allow(Open3).to receive(:capture3).with({}, *squeue_args, stdin_data: "").and_return([slurm_stdout, slurm_stderr, double("success?" => false)])
        expect { batch.get_jobs(id: '123') }.to raise_error(Slurm::Batch::Error)
      end
    end

  end

  describe "customizing bin paths" do
    let(:script) { OodCore::Job::Script.new(content: "echo 'hi'") }

    context "when calling with no config" do
      it "uses the correct command" do
        batch = OodCore::Job::Adapters::Slurm::Batch.new(cluster: "owens.osc.edu", conf: "/etc/slurm/conf/", bin: nil, bin_overrides: {})
        allow(Open3).to receive(:capture3).and_return(["job.123", "", double("success?" => true)])

        OodCore::Job::Adapters::Slurm.new(slurm: batch).submit script
        expect(Open3).to have_received(:capture3).with(anything, "sbatch", any_args)
      end
    end

    context "when calling with normal config" do
      it "uses the correct command" do
        batch = OodCore::Job::Adapters::Slurm::Batch.new(cluster: "owens.osc.edu", conf: "/etc/slurm/conf/", bin: "/bin", bin_overrides: {})
        allow(Open3).to receive(:capture3).and_return(["job.123", "", double("success?" => true)])

        OodCore::Job::Adapters::Slurm.new(slurm: batch).submit script
        expect(Open3).to have_received(:capture3).with(anything, "/bin/sbatch", any_args)
      end
    end

    context "when calling with overrides" do
      it "uses the correct command" do
        batch = OodCore::Job::Adapters::Slurm::Batch.new(cluster: "owens.osc.edu", conf: "/etc/slurm/conf/", bin: nil, bin_overrides: {"sbatch" => "not_sbatch"})
        allow(Open3).to receive(:capture3).and_return(["job.123", "", double("success?" => true)])

        OodCore::Job::Adapters::Slurm.new(slurm: batch).submit script
        expect(Open3).to have_received(:capture3).with(anything, "not_sbatch", any_args)
      end
    end
  end

  describe "setting submit_host" do 
    let (:script) { OodCore::Job::Script.new(content: "echo'hi'") } 

    context "when calling without submit_host" do 
      it "uses the correct command" do 
        batch = OodCore::Job::Adapters::Slurm::Batch.new(cluster: "owens.osc.edu", conf: "/etc/slurm/conf/", bin: nil, bin_overrides: {}, submit_host: "")
        allow(Open3).to receive(:capture3).and_return(["job.123", "", double("success?" => true)])

        OodCore::Job::Adapters::Slurm.new(slurm: batch).submit script
        expect(Open3).to have_received(:capture3).with(anything, "sbatch", '--export', 'NONE', '--parsable', '-M', 'owens.osc.edu', any_args)
      end
    end

    context "when calling with submit_host & strict_host_checking not specified" do 
      it "uses ssh wrapper & host checking defaults to true" do 
        batch = OodCore::Job::Adapters::Slurm::Batch.new(cluster: "owens.osc.edu", conf: "/etc/slurm/conf/", bin: nil, bin_overrides: {}, submit_host: "owens.osc.edu")
        allow(Open3).to receive(:capture3).and_return(["job.123", "", double("success?" => true)])

        OodCore::Job::Adapters::Slurm.new(slurm: batch).submit script
        expect(Open3).to have_received(:capture3).with(anything, 'ssh', '-p', '22', '-o', 'BatchMode=yes', '-o', 'UserKnownHostsFile=/dev/null', '-o', 'StrictHostKeyChecking=yes', 'owens.osc.edu', 'sbatch', '--export', 'NONE', '--parsable', '-M', 'owens.osc.edu', any_args)
      end
    end

    context "when strict_host_checking = 'no' && submit_host specified" do
      it "defaults host checking to yes" do
        batch = OodCore::Job::Adapters::Slurm::Batch.new(cluster: "owens.osc.edu", conf: "/etc/slurm/conf/", bin: nil, bin_overrides: {}, submit_host: "owens.osc.edu", strict_host_checking: false)
        allow(Open3).to receive(:capture3).and_return(["job.123", "", double("success?" => true)])

        OodCore::Job::Adapters::Slurm.new(slurm: batch).submit script
        expect(Open3).to have_received(:capture3).with(anything, 'ssh', '-p', '22', '-o', 'BatchMode=yes', '-o', 'UserKnownHostsFile=/dev/null', '-o', 'StrictHostKeyChecking=no', 'owens.osc.edu', 'sbatch', '--export', 'NONE', '--parsable', '-M', 'owens.osc.edu', any_args)
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

  describe "#gpus_from_gres" do
    context "when called" do
      gres_cases = [
        [nil, 0],
        ["", 0],
        ["N/A", 0],
        ["gres:gpu:v100-32g:2", 2],
        ["gres:gpu:v100-32g:2,gres:pfsdir:1", 2],
        ["gres:third-thing:sub-thing:17,gres:gpu:v100-32g:2,gres:pfsdir:1", 2],
        ["gres:third-thing:sub-thing:17,gres:pfsdir:1,gres:gpu:v100-32g:2", 2],
        ["gres:gpu:v30-12g:2,gres:gpu:v31-32g:1", 3],
        ["gres:gpu:1", 1],
        ["gres:pfsdir:ess", 0],
        ["gres/gpu:v100-32g=2", 2],
        ["gres/gpu:v100-32g=2,gres/gpu:v100-32g=4", 6],
        ["gres/gpu:v100-32g=2,gres:gpu:1,gres/gpu:v100-32g=4", 7],
        ["gres/gpu:v100-32g=2,gres:pfsdir:1", 2],
        ["gpu:p100:1,nsight:no_consume:1", 1],
        ["gpu:p100:1(IDX:0),mps:0", 1],
        ["gpu:a100:4(S:0-15)", 4],
        ["gpu:a100:3(IDX:0,2-3),mps:0", 3],
      ]
      gres_cases.each do |gc| 
        it "does not return the correct number of gpus when gres=\"#{gc[0]}\"" do
          gpus = OodCore::Job::Adapters::Slurm.gpus_from_gres(gc[0]);
          expect(gpus).to be(gc[1]);
        end
      end
    end
  end

  describe '#accounts' do
    context 'when sacctmgr returns successfully' do
      let(:slurm) { OodCore::Job::Adapters::Slurm::Batch.new(cluster: "owens", id: 'owens') }
      let(:expected_accounts) {["pzs0715", "pzs0714", "pzs1124", "pzs1118", "pzs1117", "pzs1010", "pde0006", "pas2051", "pas1871", "pas1754", "pas1604"]}

      it 'returns the correct accounts names' do
        allow(Etc).to receive(:getlogin).and_return('me')
        allow(Open3).to receive(:capture3)
                          .with({}, 'sacctmgr', '-nP', 'show', 'users', 'withassoc', 'format=account,qos', 'where', 'user=me', 'cluster=owens', {stdin_data: ''})
                          .and_return([File.read('spec/fixtures/output/slurm/sacctmgr_show_accts_owens.txt'), '',  double("success?" => true)])
        expect(subject.accounts.map(&:to_s).uniq.to_set).to eq(expected_accounts.to_set)
      end

      # TODO test for qos & cluster once the API solidifies
      it 'parses qos correctly' do
        allow(Etc).to receive(:getlogin).and_return('me')
        allow(Open3).to receive(:capture3)
                          .with({}, 'sacctmgr', '-nP', 'show', 'users', 'withassoc', 'format=account,qos', 'where', 'user=me', 'cluster=owens', {stdin_data: ''})
                          .and_return([File.read("spec/fixtures/output/slurm/sacctmgr_show_accts_owens.txt"), '',  double("success?" => true)])
        accts = subject.accounts
        acct_w_qos = accts.select { |a| a.name == 'pzs1124' }.first
        expect(acct_w_qos.qos).to eq(['owens-default', 'staff', 'phoenix', 'geophys', 'hal', 'gpt'])

        other_accts = accts - [acct_w_qos]
        other_accts.each do |acct|
          expect(acct.qos).to eq(["owens-default"])
        end
      end
    end

    context 'when sacctmgr fails' do
      let(:slurm) { OodCore::Job::Adapters::Slurm::Batch.new(cluster: 'owens', id: 'owens') }

      it 'raises the error' do
        allow(Etc).to receive(:getlogin).and_return('me')
        allow(Open3).to receive(:capture3)
                          .with({}, 'sacctmgr', '-nP', 'show', 'users', 'withassoc', 'format=account,qos', 'where', 'user=me', 'cluster=owens', {stdin_data: ''})
                          .and_return(['', 'the error message',  double("success?" => false)])

        expect { subject.accounts }.to raise_error(OodCore::Job::Adapters::Slurm::Batch::Error, 'the error message')
      end
    end

    context 'when OOD_UPCASE_ACCOUNTS is set' do
      let(:slurm) { OodCore::Job::Adapters::Slurm::Batch.new(cluster: 'owens', id: 'owens') }
      let(:expected_accounts) {["PZS0715", "PZS0714", "PZS1124", "PZS1118", "PZS1117", "PZS1010", "PDE0006", "PAS2051", "PAS1871", "PAS1754", "PAS1604"]}

      it 'returns the correct accounts' do
        allow(Etc).to receive(:getlogin).and_return('me')
        allow(Open3).to receive(:capture3)
                          .with({}, 'sacctmgr', '-nP', 'show', 'users', 'withassoc', 'format=account,qos', 'where', 'user=me', 'cluster=owens', {stdin_data: ''})
                          .and_return([File.read('spec/fixtures/output/slurm/sacctmgr_show_accts_owens.txt'), '',  double("success?" => true)])
        with_modified_env({ OOD_UPCASE_ACCOUNTS: 'true'}) do
          expect(subject.accounts.map(&:to_s).uniq.to_set).to eq(expected_accounts.to_set)
        end
      end
    end
  end

  describe '#queues' do
    context 'when scontrol returns successfully' do
      let(:slurm) { OodCore::Job::Adapters::Slurm::Batch.new }
      let(:expected_queue_names) {[
          'batch', 'debug', 'gpubackfill-parallel', 'gpubackfill-serial', 'gpudebug',
          'gpuparallel', 'gpuserial', 'hugemem', 'hugemem-parallel', 'longserial',
          'parallel', 'quick', 'serial', 'systems'
        ]}
      let(:quick_deny_accounts) {[
        'pcon0003','pcon0014','pcon0015','pcon0016','pcon0401','pcon0008','pas1429','pcon0009',
        'pcon0020','pcon0022','pcon0023','pcon0024','pcon0025','pcon0040','pcon0026','pcon0041',
        'pcon0080','pcon0100','pcon0101','pcon0120','pcon0140','pcon0160','pcon0180','pcon0200',
        'pas1901','pcon0220','pcon0240','pcon0260','pcon0280','pcon0300','pcon0320','pcon0340',
        'pcon0341','pcon0360','pcon0380','pcon0381','pcon0441','pcon0481','pcon0501','pcon0421'
      ]}

      it 'returns the correct queue info objects' do
        allow(Open3).to receive(:capture3)
                          .with({}, 'scontrol', 'show', 'part', '-o', {stdin_data: ''})
                          .and_return([File.read('spec/fixtures/output/slurm/owens_partitions.txt'), '',  double("success?" => true)])

        queues = subject.queues
        expect(queues.map(&:to_s)).to eq(expected_queue_names)

        systems_queue = queues.select { |q| q.name == 'systems' }.first
        expect(systems_queue.allow_accounts).to eq(['root', 'pzs0708', 'pzs0710', 'pzs0722'])
        expect(systems_queue.deny_accounts).to eq([])
        expect(systems_queue.gpu?).to eq(true)
        expect(systems_queue.allow_qos).to eq([])
        expect(systems_queue.deny_qos).to eq([])
        expect(systems_queue.allow_all_qos?).to eq(true)

        quick_queue = queues.select { |q| q.name == 'quick' }.first
        expect(quick_queue.allow_accounts).to eq(nil)
        expect(quick_queue.deny_accounts).to eq(quick_deny_accounts)
        expect(quick_queue.gpu?).to eq(false)
        expect(quick_queue.allow_qos).to eq([])
        expect(quick_queue.deny_qos).to eq([])
        expect(quick_queue.allow_all_qos?).to eq(true)

        gpu_queue = queues.select { |q| q.name == 'gpuserial' }.first
        expect(gpu_queue.gpu?).to eq(true)
        expect(gpu_queue.allow_qos).to eq([])
        expect(gpu_queue.deny_qos).to eq([])
        expect(gpu_queue.allow_all_qos?).to eq(true)
      end
    end

    context 'when OOD_UPCASE_ACCOUNTS is set' do
      let(:slurm) { OodCore::Job::Adapters::Slurm::Batch.new }
      let(:expected_queue_names) {[
          'batch', 'debug', 'gpubackfill-parallel', 'gpubackfill-serial', 'gpudebug',
          'gpuparallel', 'gpuserial', 'hugemem', 'hugemem-parallel', 'longserial',
          'parallel', 'quick', 'serial', 'systems'
        ]}
      let(:quick_deny_accounts) {[
        'pcon0003','pcon0014','pcon0015','pcon0016','pcon0401','pcon0008','pas1429','pcon0009',
        'pcon0020','pcon0022','pcon0023','pcon0024','pcon0025','pcon0040','pcon0026','pcon0041',
        'pcon0080','pcon0100','pcon0101','pcon0120','pcon0140','pcon0160','pcon0180','pcon0200',
        'pas1901','pcon0220','pcon0240','pcon0260','pcon0280','pcon0300','pcon0320','pcon0340',
        'pcon0341','pcon0360','pcon0380','pcon0381','pcon0441','pcon0481','pcon0501','pcon0421'
      ].map { |acct| acct.upcase } }

      it 'returns uppercase account names' do
        allow(Open3).to receive(:capture3)
                          .with({}, 'scontrol', 'show', 'part', '-o', {stdin_data: ''})
                          .and_return([File.read('spec/fixtures/output/slurm/owens_partitions.txt'), '',  double("success?" => true)])

        with_modified_env({ OOD_UPCASE_ACCOUNTS: 'true'}) do
          queues = subject.queues

          systems_queue = queues.select { |q| q.name == 'systems' }.first
          expect(systems_queue.allow_accounts).to eq(['ROOT', 'PZS0708', 'PZS0710', 'PZS0722'])
          expect(systems_queue.deny_accounts).to eq([])

          quick_queue = queues.select { |q| q.name == 'quick' }.first
          expect(quick_queue.allow_accounts).to eq(nil)
          expect(quick_queue.deny_accounts).to eq(quick_deny_accounts)
        end
      end
    end

    context 'when scontrol fails' do
      let(:slurm) { OodCore::Job::Adapters::Slurm::Batch.new }

      it 'raises the error' do

        allow(Open3).to receive(:capture3)
                          .with({}, 'scontrol', 'show', 'part', '-o', {stdin_data: ''})
                          .and_return(['', 'the error message',  double("success?" => false)])
        expect { subject.queues }.to raise_error(OodCore::Job::Adapters::Slurm::Batch::Error, 'the error message')
      end
    end
  end

  describe '#nodes' do
    context 'when sinfo returns successfully' do
      let(:slurm) { OodCore::Job::Adapters::Slurm::Batch.new }

      it 'returns the correct node information' do
        args = slurm.all_sinfo_node_fields.values.join(OodCore::Job::Adapters::Slurm::Batch::UNIT_SEPARATOR)
        args = "#{OodCore::Job::Adapters::Slurm::Batch::RECORD_SEPARATOR}#{args}"
        allow(Open3).to receive(:capture3)
                          .with({}, 'sinfo', '-ho', args, {stdin_data: ''})
                          .and_return([File.read('spec/fixtures/output/slurm/owens_nodes.txt'), '',  double("success?" => true)])

        nodes = subject.nodes
        expect(nodes.length).to eq(816)

        # select a node at random and make sure it's what you'd expect
        o0802 = subject.nodes.select { |n| n.name == "o0802" }.first
        expect(o0802.procs).to eq(28)
        expect(o0802.name).to eq('o0802')
        expect(o0802.features).to eq(['r730', 'gpu', 'eth-owens-rack19h1', 'ib-i2l1s03', 'ib-i2', 'eth-owens-rack16h1', '18', 'p100'])
      end
    end
  end
end
