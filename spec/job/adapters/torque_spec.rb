require "spec_helper"
require "ood_core/job/adapters/torque"

describe OodCore::Job::Adapters::Torque do
  # Required arguments
  let(:pbs) { double() }

  # Subject
  subject(:adapter) { described_class.new(pbs: pbs) }

  it { is_expected.to respond_to(:submit).with(1).argument.and_keywords(:after, :afterok, :afternotok, :afterany) }
  it { is_expected.to respond_to(:info_all).with(0).arguments }
  it { is_expected.to respond_to(:info).with(1).argument }
  it { is_expected.to respond_to(:status).with(1).argument }
  it { is_expected.to respond_to(:hold).with(1).argument }
  it { is_expected.to respond_to(:release).with(1).argument }
  it { is_expected.to respond_to(:delete).with(1).argument }

  describe ".new" do
    context "when :pbs not defined" do
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

    let(:pbs) { double(submit_string: "job.123") }
    let(:content) { "my batch script" }

    context "when script not defined" do
      it "raises ArgumentError" do
        expect { adapter.submit }.to raise_error(ArgumentError)
      end
    end

    subject { adapter.submit(build_script) }

    it "returns job id" do
      is_expected.to eq("job.123")
      expect(pbs).to have_received(:submit_string).with(content, queue: nil, headers: {Join_Path: "oe"}, resources: {}, envvars: {})
    end

    context "with :queue_name" do
      before { adapter.submit(build_script(queue_name: "queue")) }

      it { expect(pbs).to have_received(:submit_string).with(content, queue: "queue", headers: {Join_Path: "oe"}, resources: {}, envvars: {}) }
    end

    context "with :args" do
      before { adapter.submit(build_script(args: ["arg1", "arg2"])) }

      it { expect(pbs).to have_received(:submit_string).with(content, queue: nil, headers: {Join_Path: "oe", job_arguments: "arg1 arg2"}, resources: {}, envvars: {}) }
    end

    context "with :submit_as_hold" do
      context "as true" do
        before { adapter.submit(build_script(submit_as_hold: true)) }

        it { expect(pbs).to have_received(:submit_string).with(content, queue: nil, headers: {Join_Path: "oe", Hold_Types: :u}, resources: {}, envvars: {}) }
      end

      context "as false" do
        before { adapter.submit(build_script(submit_as_hold: false)) }

        it { expect(pbs).to have_received(:submit_string).with(content, queue: nil, headers: {Join_Path: "oe"}, resources: {}, envvars: {}) }
      end
    end

    context "with :rerunnable" do
      context "as true" do
        before { adapter.submit(build_script(rerunnable: true)) }

        it { expect(pbs).to have_received(:submit_string).with(content, queue: nil, headers: {Join_Path: "oe", Rerunable: "y"}, resources: {}, envvars: {}) }
      end

      context "as false" do
        before { adapter.submit(build_script(rerunnable: false)) }

        it { expect(pbs).to have_received(:submit_string).with(content, queue: nil, headers: {Join_Path: "oe", Rerunable: "n"}, resources: {}, envvars: {}) }
      end
    end

    context "with :job_environment" do
      before { adapter.submit(build_script(job_environment: {"key" => "value"})) }

      it { expect(pbs).to have_received(:submit_string).with(content, queue: nil, headers: {Join_Path: "oe"}, resources: {}, envvars: {"key" => "value"}) }
    end

    context "with :workdir" do
      before { adapter.submit(build_script(workdir: "/path/to/workdir")) }

      it { expect(pbs).to have_received(:submit_string).with(content, queue: nil, headers: {Join_Path: "oe", init_work_dir: Pathname.new("/path/to/workdir")}, resources: {}, envvars: {}) }
    end

    context "with :email" do
      before { adapter.submit(build_script(email: ["email1", "email2"])) }

      it { expect(pbs).to have_received(:submit_string).with(content, queue: nil, headers: {Join_Path: "oe", Mail_Users: "email1,email2"}, resources: {}, envvars: {}) }
    end

    context "with :email_on_started" do
      context "as true" do
        before { adapter.submit(build_script(email_on_started: true)) }

        it { expect(pbs).to have_received(:submit_string).with(content, queue: nil, headers: {Join_Path: "oe", Mail_Points: "b"}, resources: {}, envvars: {}) }
      end

      context "as false" do
        before { adapter.submit(build_script(email_on_started: false)) }

        it { expect(pbs).to have_received(:submit_string).with(content, queue: nil, headers: {Join_Path: "oe"}, resources: {}, envvars: {}) }
      end
    end

    context "with :email_on_terminated" do
      context "as true" do
        before { adapter.submit(build_script(email_on_terminated: true)) }

        it { expect(pbs).to have_received(:submit_string).with(content, queue: nil, headers: {Join_Path: "oe", Mail_Points: "e"}, resources: {}, envvars: {}) }
      end

      context "as false" do
        before { adapter.submit(build_script(email_on_terminated: false)) }

        it { expect(pbs).to have_received(:submit_string).with(content, queue: nil, headers: {Join_Path: "oe"}, resources: {}, envvars: {}) }
      end
    end

    context "with :email_on_started and :email_on_terminated" do
      before { adapter.submit(build_script(email_on_started: true, email_on_terminated: true)) }

      it { expect(pbs).to have_received(:submit_string).with(content, queue: nil, headers: {Join_Path: "oe", Mail_Points: "be"}, resources: {}, envvars: {}) }
    end

    context "with :job_name" do
      before { adapter.submit(build_script(job_name: "my_job")) }

      it { expect(pbs).to have_received(:submit_string).with(content, queue: nil, headers: {Join_Path: "oe", Job_Name: "my_job"}, resources: {}, envvars: {}) }
    end

    context "with :input_path" do
      before { adapter.submit(build_script(input_path: "/path/to/input")) }

      it { expect(pbs).to have_received(:submit_string).with(content, queue: nil, headers: {Join_Path: "oe"}, resources: {}, envvars: {}) }
    end

    context "with :output_path" do
      before { adapter.submit(build_script(output_path: "/path/to/output")) }

      it { expect(pbs).to have_received(:submit_string).with(content, queue: nil, headers: {Join_Path: "oe", Output_Path: Pathname.new("/path/to/output")}, resources: {}, envvars: {}) }
    end

    context "with :error_path" do
      before { adapter.submit(build_script(error_path: "/path/to/error")) }

      it { expect(pbs).to have_received(:submit_string).with(content, queue: nil, headers: {Error_Path: Pathname.new("/path/to/error")}, resources: {}, envvars: {}) }
    end

    context "with :reservation_id" do
      before { adapter.submit(build_script(reservation_id: "my_rsv")) }

      it { expect(pbs).to have_received(:submit_string).with(content, queue: nil, headers: {Join_Path: "oe", reservation_id: "my_rsv"}, resources: {}, envvars: {}) }
    end

    context "with :priority" do
      before { adapter.submit(build_script(priority: 123)) }

      it { expect(pbs).to have_received(:submit_string).with(content, queue: nil, headers: {Join_Path: "oe", Priority: 123}, resources: {}, envvars: {}) }
    end

    context "with :start_time" do
      before { adapter.submit(build_script(start_time: Time.new(2016, 11, 8, 13, 53, 54).to_i)) }

      it { expect(pbs).to have_received(:submit_string).with(content, queue: nil, headers: {Join_Path: "oe", Execution_Time: "201611081353.54"}, resources: {}, envvars: {}) }
    end

    context "with :accounting_id" do
      before { adapter.submit(build_script(accounting_id: "my_account")) }

      it { expect(pbs).to have_received(:submit_string).with(content, queue: nil, headers: {Join_Path: "oe", Account_Name: "my_account"}, resources: {}, envvars: {}) }
    end

    context "with :min_phys_memory" do
      before { adapter.submit(build_script(min_phys_memory: 1234)) }

      it { expect(pbs).to have_received(:submit_string).with(content, queue: nil, headers: {Join_Path: "oe"}, resources: {mem: "1234KB"}, envvars: {}) }
    end

    context "with :wall_time" do
      before { adapter.submit(build_script(wall_time: 94534)) }

      it { expect(pbs).to have_received(:submit_string).with(content, queue: nil, headers: {Join_Path: "oe"}, resources: {walltime: "26:15:34"}, envvars: {}) }
    end

    context "with :native" do
      context "with :headers" do
        before { adapter.submit(build_script(native: {headers: {check: "this"}})) }

        it { expect(pbs).to have_received(:submit_string).with(content, queue: nil, headers: {Join_Path: "oe", check: "this"}, resources: {}, envvars: {}) }
      end

      context "with :resources" do
        before { adapter.submit(build_script(native: {resources: {check: "this"}})) }

        it { expect(pbs).to have_received(:submit_string).with(content, queue: nil, headers: {Join_Path: "oe"}, resources: {check: "this"}, envvars: {}) }
      end

      context "with :envvars" do
        before { adapter.submit(build_script(native: {envvars: {check: "this"}})) }

        it { expect(pbs).to have_received(:submit_string).with(content, queue: nil, headers: {Join_Path: "oe"}, resources: {}, envvars: {check: "this"}) }
      end
    end

    %i(after afterok afternotok afterany).each do |after|
      context "and :#{after} is defined as a single job id" do
        before { adapter.submit(build_script, after => "job_id") }

        it { expect(pbs).to have_received(:submit_string).with(content, queue: nil, headers: {Join_Path: "oe", depend: "#{after}:job_id"}, resources: {}, envvars: {}) }
      end

      context "and :#{after} is defined as multiple job ids" do
        before { adapter.submit(build_script, after => ["job1", "job2"]) }

        it { expect(pbs).to have_received(:submit_string).with(content, queue: nil, headers: {Join_Path: "oe", depend: "#{after}:job1:job2"}, resources: {}, envvars: {}) }
      end
    end

    context "when PBS::Error is raised" do
      before { expect(pbs).to receive(:submit_string).and_raise(PBS::Error) }

      it "raises OodCore::JobAdapterError" do
        expect { subject }.to raise_error(OodCore::JobAdapterError)
      end
    end
  end

  describe "#info_all" do
    let(:pbs) { double(get_jobs: {}) }
    subject { adapter.info_all }

    it "returns an array of all the jobs" do
      is_expected.to eq([])
      expect(pbs).to have_received(:get_jobs).with(no_args)
    end

    context "when PBS::Error is raised" do
      before { expect(pbs).to receive(:get_jobs).and_raise(PBS::Error) }

      it "raises OodCore::JobAdapterError" do
        expect { subject }.to raise_error(OodCore::JobAdapterError)
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
    let(:pbs)      { double(get_job: {job_id => job_hash}) }
    subject { adapter.info(double(to_s: job_id)) }

    context "when job is not running" do
      let(:job_hash) {
        {
          :Job_Name=>"gromacs_job",
          :Job_Owner=>"cwr0448@oakley02.osc.edu",
          :job_state=>"Q",
          :queue=>"parallel",
          :server=>"oak-batch.osc.edu:15001",
          :Account_Name=>"PAA0016",
          :Checkpoint=>"u",
          :ctime=>"1478625456",
          :Error_Path=>"oakley02.osc.edu:/users/PDS0218/cwr0448/GROMACS/VANILLIN/BULK/E75/free/gromacs_job.e7964023",
          :Hold_Types=>"n",
          :Join_Path=>"oe",
          :Keep_Files=>"n",
          :Mail_Points=>"a",
          :mtime=>"1478625456",
          :Output_Path=>"oakley02.osc.edu:/users/PDS0218/cwr0448/GROMACS/VANILLIN/BULK/E75/free/gromacs_job.o7964023",
          :Priority=>"0",
          :qtime=>"1478625456",
          :Rerunable=>"True",
          :Resource_List=>{:gattr=>"PDS0218", :nodect=>"2", :nodes=>"2:ppn=12", :walltime=>"30:00:00"},
          :Shell_Path_List=>"/bin/bash",
          :euser=>"cwr0448",
          :egroup=>"PDS0218",
          :queue_type=>"E",
          :etime=>"1478625456",
          :submit_args=>"subGro.sh",
          :fault_tolerant=>"False",
          :job_radix=>"0",
          :submit_host=>"oakley02.osc.edu"
        }
      }

      it "returns correct OodCore::Job::Info object" do
        is_expected.to eq(OodCore::Job::Info.new(
          :id=>job_id,
          :status=>:queued,
          :allocated_nodes=>[],
          :submit_host=>"oakley02.osc.edu",
          :job_name=>"gromacs_job",
          :job_owner=>"cwr0448",
          :accounting_id=>"PAA0016",
          :procs=>0,
          :queue_name=>"parallel",
          :wallclock_time=>0,
          :cpu_time=>0,
          :submission_time=>"1478625456",
          :dispatch_time=>nil,
          :native=>job_hash
        ))
      end
    end

    context "when job is running" do
     let(:job_hash) {
        {
          :Job_Name=>"12_4_g_s_10hr_96_p7",
          :Job_Owner=>"osu9723@oakley01.osc.edu",
          :resources_used=>{:cput=>"73:29:59", :energy_used=>"0", :mem=>"12425624kb", :vmem=>"31499808kb", :walltime=>"06:28:23"},
          :job_state=>"R",
          :queue=>"parallel",
          :server=>"oak-batch.osc.edu:15001",
          :Account_Name=>"PAS1136",
          :Checkpoint=>"u",
          :ctime=>"1474895720",
          :Error_Path=>"oakley01.osc.edu:/users/PAS1136/osu9723/12_4_g_s_10hr_96_p7.e7539119",
          :exec_host=>"n0635/0-11+n0636/0-11+n0658/0-11+n0657/0-11+n0656/0-11+n0311/0-11+n0310/0-11+n0309/0-11",
          :exec_port=>"15003+15003+15003+15003+15003+15003+15003+15003",
          :Hold_Types=>"n",
          :Join_Path=>"oe",
          :Keep_Files=>"n",
          :Mail_Points=>"a",
          :mtime=>"1478612793",
          :Output_Path=>"oakley01.osc.edu:/users/PAS1136/osu9723/12_4_g_s_10hr_96_p7.o7539119",
          :Priority=>"0",
          :qtime=>"1474895720",
          :Rerunable=>"True",
          :Resource_List=>{:gattr=>"PAS1136", :nodect=>"8", :nodes=>"8:ppn=12", :walltime=>"09:59:00"},
          :session_id=>"9739",
          :Shell_Path_List=>"/bin/bash",
          :euser=>"osu9723",
          :egroup=>"PAS1136",
          :queue_type=>"E",
          :comment=>"could not find appropriate resources on partition ALL for the following shapes: shape[1] 96 (resources not available in any partition)",
          :etime=>"1478612727",
          :submit_args=>"12_4_g_s_10hr_96_p7.job",
          :start_time=>"1478612793",
          :Walltime=>{:Remaining=>"12581"},
          :start_count=>"1",
          :fault_tolerant=>"False",
          :job_radix=>"0",
          :submit_host=>"oakley01.osc.edu"
        }
      }

      it "returns correct OodCore::Job::Info object" do
        is_expected.to eql(OodCore::Job::Info.new(
          :id=>job_id,
          :status=>:running,
          :allocated_nodes=>[
            {:name=>"n0635", :procs=>12},
            {:name=>"n0636", :procs=>12},
            {:name=>"n0658", :procs=>12},
            {:name=>"n0657", :procs=>12},
            {:name=>"n0656", :procs=>12},
            {:name=>"n0311", :procs=>12},
            {:name=>"n0310", :procs=>12},
            {:name=>"n0309", :procs=>12}
          ],
          :submit_host=>"oakley01.osc.edu",
          :job_name=>"12_4_g_s_10hr_96_p7",
          :job_owner=>"osu9723",
          :accounting_id=>"PAS1136",
          :procs=>96,
          :queue_name=>"parallel",
          :wallclock_time=>23303,
          :cpu_time=>264599,
          :submission_time=>"1474895720",
          :dispatch_time=>"1478612793",
          :native=>job_hash
        ))
      end
    end

    context "when PBS::Error is raised" do
      before { expect(pbs).to receive(:get_job).and_raise(PBS::Error) }

      it "raises OodCore::JobAdapterError" do
        expect { subject }.to raise_error(OodCore::JobAdapterError)
      end
    end

    context "when PBS::UnkjobidError is raised" do
      before { expect(pbs).to receive(:get_job).and_raise(PBS::UnkjobidError) }

      it "returns completed OodCore::Job::Info object" do
        is_expected.to eq(OodCore::Job::Info.new(id: job_id, status: :completed))
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
    let(:pbs)       { double(get_job: {job_id => {job_state: job_state}}) }
    subject { adapter.status(double(to_s: job_id)) }

    it "request only job state from PBS" do
      subject
      expect(pbs).to have_received(:get_job).with(job_id, filters: [:job_state])
    end

    context "when job is in Q state" do
      let(:job_state) { "Q" }

      it { is_expected.to be_queued }
    end

    context "when job is in H state" do
      let(:job_state) { "H" }

      it { is_expected.to be_queued_held }
    end

    context "when job is in T state" do
      let(:job_state) { "T" }

      it { is_expected.to be_queued_held }
    end

    context "when job is in S state" do
      let(:job_state) { "S" }

      it { is_expected.to be_suspended }
    end

    context "when job is in R state" do
      let(:job_state) { "R" }

      it { is_expected.to be_running }
    end

    context "when job is in E state" do
      let(:job_state) { "E" }

      it { is_expected.to be_running }
    end

    context "when job is in C state" do
      let(:job_state) { "C" }

      it { is_expected.to be_completed }
    end

    context "when job is in unknown state" do
      let(:job_state) { "X" }

      it { is_expected.to be_undetermined }
    end

    context "when PBS::Error is raised" do
      before { expect(pbs).to receive(:get_job).and_raise(PBS::Error) }

      it "raises OodCore::JobAdapterError" do
        expect { subject }.to raise_error(OodCore::JobAdapterError)
      end
    end

    context "when PBS::UnkjobidError is raised" do
      before { expect(pbs).to receive(:get_job).and_raise(PBS::UnkjobidError) }

      it { is_expected.to be_completed }
    end
  end

  describe "#hold" do
    context "when id is not defined" do
      it "raises ArgumentError" do
        expect { adapter.hold }.to raise_error(ArgumentError)
      end
    end

    let(:job_id)    { "job_id" }
    let(:pbs)       { double(hold_job: nil) }
    subject { adapter.hold(double(to_s: job_id)) }

    it "holds job using PBS" do
      subject
      expect(pbs).to have_received(:hold_job).with(job_id)
    end

    context "when PBS::Error is raised" do
      before { expect(pbs).to receive(:hold_job).and_raise(PBS::Error) }

      it "raises OodCore::JobAdapterError" do
        expect { subject }.to raise_error(OodCore::JobAdapterError)
      end
    end

    context "when PBS::UnkjobidError is raised" do
      before { expect(pbs).to receive(:hold_job).and_raise(PBS::UnkjobidError) }

      it { is_expected.to eq(nil) }
    end
  end

  describe "#release" do
    context "when id is not defined" do
      it "raises ArgumentError" do
        expect { adapter.release }.to raise_error(ArgumentError)
      end
    end

    let(:job_id)    { "job_id" }
    let(:pbs)       { double(release_job: nil) }
    subject { adapter.release(double(to_s: job_id)) }

    it "releases job using PBS" do
      subject
      expect(pbs).to have_received(:release_job).with(job_id)
    end

    context "when PBS::Error is raised" do
      before { expect(pbs).to receive(:release_job).and_raise(PBS::Error) }

      it "raises OodCore::JobAdapterError" do
        expect { subject }.to raise_error(OodCore::JobAdapterError)
      end
    end

    context "when PBS::UnkjobidError is raised" do
      before { expect(pbs).to receive(:release_job).and_raise(PBS::UnkjobidError) }

      it { is_expected.to eq(nil) }
    end
  end

  describe "#delete" do
    context "when id is not defined" do
      it "raises ArgumentError" do
        expect { adapter.delete }.to raise_error(ArgumentError)
      end
    end

    let(:job_id)    { "job_id" }
    let(:pbs)       { double(delete_job: nil) }
    subject { adapter.delete(double(to_s: job_id)) }

    it "deletes job using PBS" do
      subject
      expect(pbs).to have_received(:delete_job).with(job_id)
    end

    context "when PBS::Error is raised" do
      before { expect(pbs).to receive(:delete_job).and_raise(PBS::Error) }

      it "raises OodCore::JobAdapterError" do
        expect { subject }.to raise_error(OodCore::JobAdapterError)
      end
    end

    context "when PBS::UnkjobidError is raised" do
      before { expect(pbs).to receive(:delete_job).and_raise(PBS::UnkjobidError) }

      it { is_expected.to eq(nil) }
    end

    context "when PBS::BadstateError is raised" do
      before { expect(pbs).to receive(:delete_job).and_raise(PBS::BadstateError) }

      it { is_expected.to eq(nil) }
    end
  end
end
