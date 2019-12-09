require "spec_helper"
require "ood_core/job/adapters/pbspro"

describe OodCore::Job::Adapters::PBSPro do
  # Required arguments
  let(:pbspro) { double() }
  let(:qstat_factor) { nil }

  # Subject
  subject(:adapter) { described_class.new(pbspro: pbspro, qstat_factor: qstat_factor) }

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
    context "when :pbspro not defined" do
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

    let(:pbspro)  { double(submit_string: "job.123") }
    let(:content) { "my batch script" }

    context "when script not defined" do
      it "raises ArgumentError" do
        expect { adapter.submit }.to raise_error(ArgumentError)
      end
    end

    subject { adapter.submit(build_script) }

    it "returns job id" do
      is_expected.to eq("job.123")
      expect(pbspro).to have_received(:submit_string).with(content, args: ["-j", "oe"], chdir: nil)
    end

    context "with :queue_name" do
      before { adapter.submit(build_script(queue_name: "queue")) }

      it { expect(pbspro).to have_received(:submit_string).with(content, args: ["-q", "queue", "-j", "oe"], chdir: nil) }
    end

    context "with :args" do
      before { adapter.submit(build_script(args: ["arg1", "arg2"])) }

      it { expect(pbspro).to have_received(:submit_string).with(content, args: ["-j", "oe"], chdir: nil) }
    end

    context "with :submit_as_hold" do
      context "as true" do
        before { adapter.submit(build_script(submit_as_hold: true)) }

        it { expect(pbspro).to have_received(:submit_string).with(content, args: ["-h", "-j", "oe"], chdir: nil) }
      end

      context "as false" do
        before { adapter.submit(build_script(submit_as_hold: false)) }

        it { expect(pbspro).to have_received(:submit_string).with(content, args: ["-j", "oe"], chdir: nil) }
      end
    end

    context "with :rerunnable" do
      context "as true" do
        before { adapter.submit(build_script(rerunnable: true)) }

        it { expect(pbspro).to have_received(:submit_string).with(content, args: ["-r", "y", "-j", "oe"], chdir: nil) }
      end

      context "as false" do
        before { adapter.submit(build_script(rerunnable: false)) }

        it { expect(pbspro).to have_received(:submit_string).with(content, args: ["-r", "n", "-j", "oe"], chdir: nil) }
      end
    end

    context "with :job_environment" do
      before { adapter.submit(build_script(job_environment: {"key" => "value"})) }

      it { expect(pbspro).to have_received(:submit_string).with(content, args: ["-v", "key=value", "-j", "oe"], chdir: nil) }
    end

    context "with :workdir" do
      before { adapter.submit(build_script(workdir: "/path/to/workdir")) }

      it { expect(pbspro).to have_received(:submit_string).with(content, args: ["-j", "oe"], chdir: Pathname.new("/path/to/workdir")) }
    end

    context "with :email" do
      before { adapter.submit(build_script(email: ["email1", "email2"])) }

      it { expect(pbspro).to have_received(:submit_string).with(content, args: ["-M", "email1,email2", "-j", "oe"], chdir: nil) }
    end

    context "with :email_on_started" do
      context "as true" do
        before { adapter.submit(build_script(email_on_started: true)) }

        it { expect(pbspro).to have_received(:submit_string).with(content, args: ["-m", "b", "-j", "oe"], chdir: nil) }
      end

      context "as false" do
        before { adapter.submit(build_script(email_on_started: false)) }

        it { expect(pbspro).to have_received(:submit_string).with(content, args: ["-j", "oe"], chdir: nil) }
      end
    end

    context "with :email_on_terminated" do
      context "as true" do
        before { adapter.submit(build_script(email_on_terminated: true)) }

        it { expect(pbspro).to have_received(:submit_string).with(content, args: ["-m", "e", "-j", "oe"], chdir: nil) }
      end

      context "as false" do
        before { adapter.submit(build_script(email_on_terminated: false)) }

        it { expect(pbspro).to have_received(:submit_string).with(content, args: ["-j", "oe"], chdir: nil) }
      end
    end

    context "with :email_on_started and :email_on_terminated" do
      before { adapter.submit(build_script(email_on_started: true, email_on_terminated: true)) }

      it { expect(pbspro).to have_received(:submit_string).with(content, args: ["-m", "be", "-j", "oe"], chdir: nil) }
    end

    context "with :job_name" do
      before { adapter.submit(build_script(job_name: "my_job")) }

      it { expect(pbspro).to have_received(:submit_string).with(content, args: ["-N", "my_job", "-j", "oe"], chdir: nil) }
    end

    context "with :shell_path" do
      before { adapter.submit(build_script(shell_path: "/path/to/shell")) }

      it { expect(pbspro).to have_received(:submit_string).with(content, args: ["-S", Pathname.new("/path/to/shell"), "-j", "oe"], chdir: nil) }
    end

    context "with :input_path" do
      before { adapter.submit(build_script(input_path: "/path/to/input")) }

      it { expect(pbspro).to have_received(:submit_string).with(content, args: ["-j", "oe"], chdir: nil) }
    end

    context "with :output_path" do
      before { adapter.submit(build_script(output_path: "/path/to/output")) }

      it { expect(pbspro).to have_received(:submit_string).with(content, args: ["-o", Pathname.new("/path/to/output"), "-j", "oe"], chdir: nil) }
    end

    context "with :error_path" do
      before { adapter.submit(build_script(error_path: "/path/to/error")) }

      it { expect(pbspro).to have_received(:submit_string).with(content, args: ["-e", Pathname.new("/path/to/error")], chdir: nil) }
    end

    context "with :reservation_id" do
      before { adapter.submit(build_script(reservation_id: "my_rsv")) }

      it { expect(pbspro).to have_received(:submit_string).with(content, args: ["-q", "my_rsv", "-j", "oe"], chdir: nil) }
    end

    context "with :priority" do
      before { adapter.submit(build_script(priority: 123)) }

      it { expect(pbspro).to have_received(:submit_string).with(content, args: ["-p", 123, "-j", "oe"], chdir: nil) }
    end

    context "with :start_time" do
      before { adapter.submit(build_script(start_time: Time.new(2016, 11, 8, 13, 53, 54).to_i)) }

      it { expect(pbspro).to have_received(:submit_string).with(content, args: ["-a", "201611081353.54", "-j", "oe"], chdir: nil) }
    end

    context "with :accounting_id" do
      before { adapter.submit(build_script(accounting_id: "my_account")) }

      it { expect(pbspro).to have_received(:submit_string).with(content, args: ["-A", "my_account", "-j", "oe"], chdir: nil) }
    end

    context "with :wall_time" do
      before { adapter.submit(build_script(wall_time: 94534)) }

      it { expect(pbspro).to have_received(:submit_string).with(content, args: ["-l", "walltime=26:15:34", "-j", "oe"], chdir: nil) }
    end

    context "with :native" do
      before { adapter.submit(build_script(native: ["A", "B", "C"])) }

      it { expect(pbspro).to have_received(:submit_string).with(content, args: ["-j", "oe", "A", "B", "C"], chdir: nil) }
    end

    %i(after afterok afternotok afterany).each do |after|
      context "and :#{after} is defined as a single job id" do
        before { adapter.submit(build_script, after => "job_id") }

        it { expect(pbspro).to have_received(:submit_string).with(content, args: ["-W", "depend=#{after}:job_id", "-j", "oe"], chdir: nil) }
      end

      context "and :#{after} is defined as multiple job ids" do
        before { adapter.submit(build_script, after => ["job1", "job2"]) }

        it { expect(pbspro).to have_received(:submit_string).with(content, args: ["-W", "depend=#{after}:job1:job2", "-j", "oe"], chdir: nil) }
      end
    end

    context "when OodCore::Job::Adapters::PBSPro::Batch::Error is raised" do
      before { expect(pbspro).to receive(:submit_string).and_raise(OodCore::Job::Adapters::PBSPro::Batch::Error) }

      it "raises OodCore::JobAdapterError" do
        expect { subject }.to raise_error(OodCore::JobAdapterError)
      end
    end
  end

  describe "#info_all" do
    let(:pbspro) { double(get_jobs: {}) }
    subject { adapter.info_all }

    it "returns an array of all the jobs" do
      is_expected.to eq([])
      expect(pbspro).to have_received(:get_jobs).with(no_args)
    end

    context "when OodCore::Job::Adapters::PBSPro::Batch::Error is raised" do
      before { expect(pbspro).to receive(:get_jobs).and_raise(OodCore::Job::Adapters::PBSPro::Batch::Error) }

      it "raises OodCore::JobAdapterError" do
        expect { subject }.to raise_error(OodCore::JobAdapterError)
      end
    end
  end

  describe "#info_where_owner" do
    let(:job_owner) { "job_owner" }
    let(:pbspro) { double(select_jobs: job_ids) }
    subject { adapter.info_where_owner(job_owner) }

    context "owner has no jobs" do
      let(:job_ids) { [] }

      it { is_expected.to eq([]) }
    end

    context "when given list of owners" do
      let(:job_ids) { [] }
      let(:job_owner) { ["job_owner_1", "job_owner_2"] }

      it "uses comma delimited owner list" do
        expect(pbspro).to receive(:select_jobs).with(args: ["-u", job_owner.join(",")])
        is_expected.to eq([])
      end
    end

    context "when owner has multiple jobs" do
      let(:qstat_factor) { 1.00 }
      let(:job_ids) { [ "job_id_1", "job_id_2" ] }
      let(:job_hash_1) {
        {
          :job_id=>"job_id_1",
          :Job_Owner=>"#{job_owner}@server",
          :job_state=>"Q",
        }
      }
      let(:job_hash_2) {
        {
          :job_id=>"job_id_2",
          :Job_Owner=>"#{job_owner}@server",
          :job_state=>"Q",
        }
      }

      before do
        allow(pbspro).to receive(:get_jobs).with(id: "job_id_1").and_return([job_hash_1])
        allow(pbspro).to receive(:get_jobs).with(id: "job_id_2").and_return([job_hash_2])
      end

      it "returns list of OodCore::Job::Info objects" do
        is_expected.to eq([
          OodCore::Job::Info.new(
            :id=>"job_id_1",
            :job_owner=>job_owner,
            :submit_host=>"server",
            :status=>:queued,
            :procs=>0,
            :native=>job_hash_1
          ),
          OodCore::Job::Info.new(
            :id=>"job_id_2",
            :job_owner=>job_owner,
            :submit_host=>"server",
            :status=>:queued,
            :procs=>0,
            :native=>job_hash_2
          )
        ])
      end

      context "and when OodCore::Job::Adapters::PBSPro::Batch::Error is raised" do
        let(:msg) { "random error" }
        before do
          allow(pbspro).to receive(:get_jobs).with(id: "job_id_1").and_raise(OodCore::Job::Adapters::PBSPro::Batch::Error, msg)
        end

        it "raises OodCore::JobAdapterError" do
          expect { subject }.to raise_error(OodCore::JobAdapterError)
        end

        context "due to invalid job id" do
          let(:msg) { "qstat: Unknown Job Id job_id\n" }

          it "returns list of OodCore::Job::Info objects with a completed job" do
            is_expected.to eq([
              OodCore::Job::Info.new(
                :id=>"job_id_1",
                :status=>:completed
              ),
              OodCore::Job::Info.new(
                :id=>"job_id_2",
                :job_owner=>job_owner,
                :submit_host=>"server",
                :status=>:queued,
                :procs=>0,
                :native=>job_hash_2
              )
            ])
          end
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
    let(:pbspro)   { double(get_jobs: [job_hash]) }
    subject { adapter.info(double(to_s: job_id)) }

    context "when job is not running" do
      let(:job_hash) {
        {
          :job_id=>job_id,
          :Job_Name=>"be_5",
          :Job_Owner=>"trzask@login3.cm.cluster",
          :job_state=>"Q",
          :queue=>"oc_windfall",
          :server=>"head1.cm.cluster",
          :Checkpoint=>"u",
          :ctime=>"Fri Jun 23 06:31:33 2017",
          :Error_Path=>"login3.cm.cluster:/home/u30/trzask/ocelote/be_s/5/be_5.e718894",
          :group_list=>"ludwik",
          :Hold_Types=>"n",
          :Join_Path=>"n",
          :Keep_Files=>"n",
          :Mail_Points=>"a",
          :mtime=>"Fri Jun 23 06:31:33 2017",
          :Output_Path=>"login3.cm.cluster:/home/u30/trzask/ocelote/be_s/5/be_5.o718894",
          :Priority=>"0",
          :qtime=>"Fri Jun 23 06:31:33 2017",
          :Rerunable=>"True",
          :Resource_List=>{
            :cput=>"3600:00:00",
            :mem=>"80gb",
            :mpiprocs=>"14",
            :ncpus=>"14",
            :nodect=>"1",
            :place=>"free",
            :pvmem=>"80gb",
            :select=>"1:ncpus=14:mem=80gb:pcmem=6gb:nodetype=standard:mpiprocs=14",
            :walltime=>"240:00:00"
          },
          :substate=>"10",
          :Variable_List=>"PBS_O_SYSTEM=Linux,PBS_O_SHELL=/bin/bash,PBS_O_HOME=/home/u30/trzask,PBS_O_LOGNAME=trzask,PBS_O_WORKDIR=/home/u30/trzask/ocelote/be_s/5,PBS_O_LANG=en_US.UTF-8,PBS_O_PATH=/cm/local/apps/gcc/5.2.0/bin:/cm/shared/apps/pbspro/13.0.2.153173/sbin:/cm/shared/apps/pbspro/13.0.2.153173/bin:/cm/shared/uabin:/usr/lib64/qt-3.3/bin:/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin:/sbin:/usr/sbin:/cm/local/apps/environment-modules/3.2.10/bin:/home/u30/trzask/bin,PBS_O_MAIL=/var/spool/mail/trzask,PBS_O_QUEUE=windfall,PBS_O_HOST=login3.cm.cluster",
          :comment=>"Not Running: Insufficient amount of resource qlist",
          :etime=>"Fri Jun 23 06:31:33 2017",
          :Submit_arguments=>"run28",
          :project=>"_pbs_project_default"
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
          :job_id=>job_id,
          :Job_Name=>"WT_tnc-Z08_eq",
          :Job_Owner=>"lszatkowski@login3.cm.cluster",
          :resources_used=>{
            :cpupercent=>"0",
            :cput=>"00:00:05",
            :mem=>"6264kb",
            :ncpus=>"56",
            :vmem=>"279596kb",
            :walltime=>"57:09:02"
          },
          :job_state=>"R",
          :queue=>"oc_high_pri",
          :server=>"head1.cm.cluster",
          :Checkpoint=>"u",
          :ctime=>"Tue Jun 20 21:23:59 2017",
          :Error_Path=>"login3.cm.cluster:/home/u14/lszatkowski/lszatkowski/FD-CTF/Z08/WT_TnC_Z08/WT_tnc-Z08_eq.e716810",
          :exec_host=>"i15n12/0*28+i15n13/0*28",
          :exec_vnode=>"(i15n12:ncpus=28:mem=146800640kb:ngpus=1)+(i15n13:ncpus=28:mem=146800640kb:ngpus=1)",
          :group_list=>"sschwartz",
          :Hold_Types=>"n",
          :Join_Path=>"n",
          :Keep_Files=>"n",
          :Mail_Points=>"be",
          :Mail_Users=>"lszatkowski@email.arizona.edu",
          :mtime=>"Tue Jun 20 21:24:48 2017",
          :Output_Path=>"login3.cm.cluster:/home/u14/lszatkowski/lszatkowski/FD-CTF/Z08/WT_TnC_Z08/WT_tnc-Z08_eq.o716810",
          :Priority=>"0",
          :qtime=>"Tue Jun 20 21:23:59 2017",
          :Rerunable=>"True",
          :Resource_List=>{
            :cput=>"12000:00:00",
           :mem=>"280gb",
           :mpiprocs=>"56",
           :ncpus=>"56",
           :ngpus=>"2",
           :nodect=>"2",
           :place=>"free",
           :select=>"2:ncpus=28:mem=140gb:ngpus=1:pcmem=6gb:nodetype=gpu:mpiprocs=28",
           :walltime=>"192:00:00"
          },
          :stime=>"Tue Jun 20 21:24:47 2017",
          :session_id=>"15079",
          :jobdir=>"/home/u14/lszatkowski",
          :substate=>"42",
          :Variable_List=>"PBS_O_SYSTEM=Linux,PBS_O_SHELL=/bin/bash,PBS_O_HOME=/home/u14/lszatkowski,PBS_O_LOGNAME=lszatkowski,PBS_O_WORKDIR=/home/u14/lszatkowski/lszatkowski/FD-CTF/Z08/WT_TnC_Z08,PBS_O_LANG=en_US.UTF-8,PBS_O_PATH=.:/home/u18/antoniou/local/bin:/cm/local/apps/gcc/5.2.0/bin:/cm/shared/apps/pbspro/13.0.2.153173/sbin:/cm/shared/apps/pbspro/13.0.2.153173/bin:/cm/shared/uabin:/usr/lib64/qt-3.3/bin:/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin:/sbin:/usr/sbin:/cm/local/apps/environment-modules/3.2.10/bin,PBS_O_MAIL=/var/spool/mail/lszatkowski,PBS_O_QUEUE=high_pri,PBS_O_HOST=login3.cm.cluster",
          :comment=>"Job run at Tue Jun 20 at 21:24 on (i15n12:ncpus=28:mem=146800640kb:ngpus=1)+(i15n13:ncpus=28:mem=146800640kb:ngpus=1)",
          :etime=>"Tue Jun 20 21:23:59 2017",
          :run_count=>"1",
          :Submit_arguments=>"namd_OCg2_WT-TnC-Z08_eq.pbs",
          :project=>"_pbs_project_default"
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
      let(:pbspro) { double(get_jobs: []) }

      it "returns completed OodCore::Job::Info object" do
        is_expected.to eq(OodCore::Job::Info.new(id: job_id, status: :completed))
      end
    end

    context "when OodCore::Job::Adapters::PBSPro::Batch::Error is raised" do
      let(:msg) { "random error" }
      before { expect(pbspro).to receive(:get_jobs).and_raise(OodCore::Job::Adapters::PBSPro::Batch::Error, msg) }

      it "raises OodCore::JobAdapterError" do
        expect { subject }.to raise_error(OodCore::JobAdapterError)
      end

      context "due to invalid job id" do
        let(:msg) { "qstat: Unknown Job Id job_id\n" }

        it "returns completed OodCore::Job::Info object" do
          is_expected.to eq(OodCore::Job::Info.new(id: job_id, status: :completed))
        end
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
    let(:pbspro)    { double(get_jobs: [job_id: job_id, job_state: job_state]) }
    subject { adapter.status(double(to_s: job_id)) }

    it "request only job state from PBS" do
      subject
      expect(pbspro).to have_received(:get_jobs).with(id: job_id)
    end

    context "when job is in Q state" do
      let(:job_state) { "Q" }

      it { is_expected.to be_queued }
    end

    context "when job is in W state" do
      let(:job_state) { "W" }

      it { is_expected.to be_queued_held }
    end

    context "when job is in H state" do
      let(:job_state) { "H" }

      it { is_expected.to be_queued_held }
    end

    context "when job is in T state" do
      let(:job_state) { "T" }

      it { is_expected.to be_queued_held }
    end

    context "when job is in M state" do
      let(:job_state) { "M" }

      it { is_expected.to be_completed }
    end

    context "when job is in R state" do
      let(:job_state) { "R" }

      it { is_expected.to be_running }
    end

    context "when job is in S state" do
      let(:job_state) { "S" }

      it { is_expected.to be_suspended }
    end

    context "when job is in U state" do
      let(:job_state) { "U" }

      it { is_expected.to be_suspended }
    end

    context "when job is in E state" do
      let(:job_state) { "E" }

      it { is_expected.to be_running }
    end

    context "when job is in F state" do
      let(:job_state) { "F" }

      it { is_expected.to be_completed }
    end

    context "when job is in X state" do
      let(:job_state) { "X" }

      it { is_expected.to be_completed }
    end

    context "when job is in unknown state" do
      let(:job_state) { "Z" }

      it { is_expected.to be_undetermined }
    end

    context "when OodCore::Job::Adapters::PBSPro::Batch::Error is raised" do
      let(:msg) { "random error" }
      before { expect(pbspro).to receive(:get_jobs).and_raise(OodCore::Job::Adapters::PBSPro::Batch::Error, msg) }

      it "raises OodCore::JobAdapterError" do
        expect { subject }.to raise_error(OodCore::JobAdapterError)
      end

      context "due to invalid job id" do
        let(:msg) { "qstat: Unknown Job Id job_id\n" }

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
    let(:pbspro)  { double(hold_job: nil) }
    subject { adapter.hold(double(to_s: job_id)) }

    it "holds job using OodCore::Job::Adapters::PBSPro::Batch" do
      subject
      expect(pbspro).to have_received(:hold_job).with(job_id)
    end

    context "when OodCore::Job::Adapters::PBSPro::Batch::Error is raised" do
      let(:msg) { "random error" }
      before { expect(pbspro).to receive(:hold_job).and_raise(OodCore::Job::Adapters::PBSPro::Batch::Error, msg) }

      it "raises OodCore::JobAdapterError" do
        expect { subject }.to raise_error(OodCore::JobAdapterError)
      end

      context "due to invalid job id" do
        let(:msg) { "qhold: Unknown Job Id job_id\n" }

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
    let(:pbspro)  { double(release_job: nil) }
    subject { adapter.release(double(to_s: job_id)) }

    it "releases job using OodCore::Job::Adapters::PBSPro::Batch" do
      subject
      expect(pbspro).to have_received(:release_job).with(job_id)
    end

    context "when OodCore::Job::Adapters::PBSPro::Batch::Error is raised" do
      let(:msg) { "random error" }
      before { expect(pbspro).to receive(:release_job).and_raise(OodCore::Job::Adapters::PBSPro::Batch::Error, msg) }

      it "raises OodCore::JobAdapterError" do
        expect { subject }.to raise_error(OodCore::JobAdapterError)
      end

      context "due to invalid job id" do
        let(:msg) { "qrls: Unknown Job Id job_id\n" }

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
    let(:pbspro) { double(delete_job: nil) }
    subject { adapter.delete(double(to_s: job_id)) }

    it "deletes job using OodCore::Job::Adapters::PBSPro::Batch" do
      subject
      expect(pbspro).to have_received(:delete_job).with(job_id)
    end

    context "when OodCore::Job::Adapters::PBSPro::Batch::Error is raised" do
      let(:msg) { "random error" }
      before { expect(pbspro).to receive(:delete_job).and_raise(OodCore::Job::Adapters::PBSPro::Batch::Error, msg) }

      it "raises OodCore::JobAdapterError" do
        expect { subject }.to raise_error(OodCore::JobAdapterError)
      end

      context "due to invalid job id" do
        let(:msg) { "qdel: Unknown Job Id job_id\n" }

        it { is_expected.to be_nil }
      end
    end
  end

  describe "customizing bin paths" do
    let(:script) { OodCore::Job::Script.new(content: "echo 'hi'") }

    context "when calling with no config" do
      it "uses qsub" do
        batch = OodCore::Job::Adapters::PBSPro::Batch.new(host: "owens.osc.edu", pbs_exec: nil, bin_overrides: {})
        allow(Open3).to receive(:capture3).and_return(["job.123", "", double("success?" => true)])

        OodCore::Job::Adapters::PBSPro.new(pbspro: batch, qstat_factor: nil).submit script
        expect(Open3).to have_received(:capture3).with(anything, "qsub", any_args)
      end
    end

    context "when calling with normal config" do
      it "uses qsub" do
        batch = OodCore::Job::Adapters::PBSPro::Batch.new(host: "owens.osc.edu", pbs_exec: "/opt/pbspro", bin_overrides: {})
        allow(Open3).to receive(:capture3).and_return(["job.123", "", double("success?" => true)])

        OodCore::Job::Adapters::PBSPro.new(pbspro: batch, qstat_factor: nil).submit script
        expect(Open3).to have_received(:capture3).with(anything, "/opt/pbspro/bin/qsub", any_args)
      end
    end

    context "when calling with overrides" do
      it "uses qsub" do
        batch = OodCore::Job::Adapters::PBSPro::Batch.new(host: "owens.osc.edu", pbs_exec: "/opt/pbspro", bin_overrides: {"qsub" => "/custom/qsubber"})
        allow(Open3).to receive(:capture3).and_return(["job.123", "", double("success?" => true)])

        OodCore::Job::Adapters::PBSPro.new(pbspro: batch, qstat_factor: nil).submit script
        expect(Open3).to have_received(:capture3).with(anything, "/custom/qsubber", any_args)
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
