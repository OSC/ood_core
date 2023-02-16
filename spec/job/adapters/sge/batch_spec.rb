require "spec_helper"
require "ood_core/job/adapters/sge"
require "ood_core/job/adapters/sge/batch"

def load_resource_file(file_name)
  File.open(file_name, 'r') { |f| f.read }
end

describe OodCore::Job::Adapters::Sge::Batch do
  subject(:batch) {described_class.new({:cluster => '', :bin => ''})}
  let(:jobs_from_qstat) {[
    OodCore::Job::Info.new( # Running job, w/ project
      :id => '88',
      :job_owner => 'vagrant',
      :accounting_id => 'project_a',
      :job_name => 'job_15',
      :status => :running,
      :procs => 1,
      :queue_name => 'general.q',
      :dispatch_time => DateTime.parse('2018-10-10T14:37:16').to_time.to_i,
      :wallclock_limit => 360,
      :wallclock_time => Time.now.to_i - DateTime.parse('2018-10-10T14:37:16').to_time.to_i,
      :native => {
        :ST_name=>"", 
        :JB_job_number=>"88", 
        :JB_owner=>"vagrant", 
        :JB_project=>"project_a"
      }
    ),
    OodCore::Job::Info.new( # Queued job, w/ project
      :id => '1045',
      :job_owner => 'vagrant',
      :accounting_id => 'project_b',
      :job_name => 'job_RQ',
      :status => :queued,
      :procs => 1,
      :queue_name => 'general.q',
      :submission_time => DateTime.parse('2018-10-09T18:47:05').to_time.to_i,
      :wallclock_limit => 360,
      :wallclock_time => 0,
      :native => {
        :JB_job_number=>"1045", 
        :JB_owner=>"vagrant", 
        :JB_project=>"project_b", 
        :JB_submission_time=>"2018-10-09T18:47:05"
      }
    ),
    OodCore::Job::Info.new( # Queued job w/o project
      :id => '1046',
      :job_owner => 'vagrant',
      :job_name => 'job_RR',
      :status => :queued,
      :procs => 1,
      :queue_name => 'general.q',
      :submission_time => DateTime.parse('2018-10-09T18:47:05').to_time.to_i,
      :wallclock_limit => 360,
      :wallclock_time => 0,
      :native => {
        :JB_job_number=>"1046", 
        :JB_owner=>"vagrant", 
        :JB_submission_time=>"2018-10-09T18:47:05"
      },
      :tasks => [
        { :id => '1', :status => :queued },
        { :id => '3', :status => :queued },
        { :id => '5', :status => :queued },
        { :id => '7', :status => :queued },
        { :id => '9', :status => :queued }
      ]
    ),
    OodCore::Job::Info.new( # Held job w/o project
      :id => '44',
      :job_owner => 'vagrant',
      :job_name => 'c_d',
      :status => :queued_held,
      :procs => 1,
      :queue_name => 'general.q',
      :submission_time => DateTime.parse('2018-10-09T18:35:12').to_time.to_i,
      :wallclock_limit => 360,
      :wallclock_time => 0,
      :native => {
        :JB_job_number=>"44", 
        :JB_owner=>"vagrant", 
        :JB_submission_time=>"2018-10-09T18:35:12"
      }
    )
  ]}

  let(:job_from_qstat_jr) {
    OodCore::Job::Info.new(
      :accounting_id => 'xjzhou_prj',
      :allocated_nodes => [],
      :cpu_time => nil,
      :dispatch_time => Time.at(1541444223),
      :id => "4147342",
      :job_name => "cfSNV_0merged_split_pileup_241.FLASH.recal_10.pbs",
      :job_owner => "shuoli",
      :native =>{
        :ST_name=>"",
        :JB_job_number=>"4147342",
        :JB_exec_file=>"job_scripts/4147342",
        :JB_submission_time=>"1541444183",
        :JB_owner=>"shuoli",
        :JB_uid=>"13287",
        :JB_group=>"xjzhou",
        :JB_gid=>"12426",
        :JB_account=>"sge",
        :JB_project=>"xjzhou_prj",
        :JB_notify=>"false",
        :JB_job_name=>"cfSNV_0merged_split_pileup_241.FLASH.recal_10.pbs",
        :JB_jobshare=>"0",
        :JB_script_file=>"cfSNV_0merged_split_pileup_241.FLASH.recal_10.pbs",
        :JB_cwd=>"/u/project/xjzhou/shuoli/Zo_WES_plasma_SC1810033_10312018/code/0",
        :JB_deadline=>"0",
        :JB_execution_time=>"0",
        :JB_checkpoint_attr=>"0",
        :JB_checkpoint_interval=>"0",
        :JB_reserve=>"false",
        :JB_priority=>"1024",
        :JB_restart=>"0",
        :JB_verify=>"0",
        :JB_script_size=>"0",
        :JB_version=>"0",
        :JB_type=>"0"
      },
      :procs => 1,
      :queue_name => nil,
      :status => :running,
      :submission_time => Time.at(1541444183),
      :submit_host => nil,
      :wallclock_limit => 86400,
      :wallclock_time => Time.now.to_i - 1541444223,
    )
  }

  let(:job_from_qstat_jr_mutlislot) {
    OodCore::Job::Info.new(
      :accounting_id => nil,
      :allocated_nodes => [],
      :cpu_time => nil,
      :dispatch_time => nil,
      :id => "942195",
      :job_name => "RemoteDesktop",
      :job_owner => "smatott",
      :native => {
        :ST_name=>"",
        :JB_job_number=>"942195",
        :JB_exec_file=>"job_scripts/942195",
        :JB_submission_time=>"1576525304",
        :JB_owner=>"smatott",
        :JB_uid=>"1105",
        :JB_group=>"packages",
        :JB_gid=>"3002",
        :JB_account=>"sge",
        :JB_notify=>"false",
        :JB_job_name=>"RemoteDesktop",
        :PN_path=> "/mnt/lustre/users/smatott/ondemand/data/sys/dashboard/batch_connect/sys/bc_desktop/hpc/output/9beca517-07fa-4379-8eb7-934460846a19/output.log",
        :JB_jobshare=>"0",
        :JB_script_file=>"STDIN",
        :JB_cwd=> "/mnt/lustre/users/smatott/ondemand/data/sys/dashboard/batch_connect/sys/bc_desktop/hpc/output/9beca517-07fa-4379-8eb7-934460846a19",
        :JB_deadline=>"0",
        :JB_execution_time=>"0",
        :JB_checkpoint_attr=>"0",
        :JB_checkpoint_interval=>"0",
        :JB_reserve=>"false",
        :JB_priority=>"1024",
        :JB_restart=>"0",
        :JB_verify=>"0",
        :JB_script_size=>"0",
        :JB_version=>"0",
        :JB_type=>"0"
      },
      :procs => 16,
      :queue_name => 'all.q',
      :status => :running,
      :submission_time => Time.at(1576525304),
      :submit_host => nil,
      :wallclock_limit => 518400,
      :wallclock_time => nil,
    )
  }

  let(:job_from_uge_qstat_jr) {
    OodCore::Job::Info.new(
      :accounting_id => 'communitycluster',
      :allocated_nodes => [],
      :cpu_time => nil,
      :dispatch_time => Time.at(1592928425),
      :id => "748172",
      :job_name => "jupyter_interactive",
      :job_owner => "johrstrom",
      :native => {
        :ST_name=>"/export/uge/bin/lx-amd64/qsub -wd /home/johrstrom/ondemand/data/sys/dashboard/batch_connect/sys/jupyter/output/a4a46499-77d9-4334-bef2-71dd0a0857f6 -N jupyter_interactive -o /home/johrstrom/ondemand/data/sys/dashboard/batch_connect/sys/jupyter/output/a4a46499-77d9-4334-bef2-71dd0a0857f6/output.log -q ondemand -l h_rt=04:00:00 -P communitycluster -V -pe sm 11 hpcc ",
        :JB_job_number=>"748172",
        :JB_job_name=>"jupyter_interactive",
        :JB_version=>"0",
        :JB_project=>"communitycluster",
        :JB_exec_file=>"job_scripts/748172",
        :JB_script_file=>"STDIN",
        :JB_script_size=>"0",
        :JB_submission_time=>"1592928409331",
        :JB_execution_time=>"0",
        :JB_deadline=>"0",
        :JB_owner=>"johrstrom",
        :JB_uid=>"99577",
        :JB_group=>"hpcc",
        :JB_gid=>"101",
        :JB_account=>"sge",
        :JB_cwd=>"/home/johrstrom/ondemand/data/sys/dashboard/batch_connect/sys/jupyter/output/a4a46499-77d9-4334-bef2-71dd0a0857f6",
        :JB_notify=>"false",
        :JB_type=>"0",
        :JB_reserve=>"false",
        :JB_priority=>"0",
        :JB_jobshare=>"0",
        :JB_verify=>"0",
        :JB_checkpoint_attr=>"0",
        :JB_checkpoint_interval=>"0",
        :JB_restart=>"0",
        :PN_path=>"/home/johrstrom/ondemand/data/sys/dashboard/batch_connect/sys/jupyter/output/a4a46499-77d9-4334-bef2-71dd0a0857f6/output.log"
      },
      :procs => 11,
      :queue_name => 'ondemand',
      :status => :running,
      :submission_time => Time.at(1592928409),
      :submit_host => nil,
      :wallclock_limit => 14400,
      :wallclock_time => Time.now.to_i - 1592928425,
    )
  }

  describe "#new" do
    context "when bin is nil" do
      it "does not crash" do
        described_class.new({cluster: '', bin: nil})
      end
    end
  end

  describe "#get_all" do
    context "when no owner is set" do
      before {
        allow(batch).to receive(:call) { load_resource_file('spec/job/adapters/sge/output_examples/qstat_r.xml') }
      }

      it "returns the correct job info" do
        expect(batch.get_all).to eq(jobs_from_qstat)
      end
    end

    context "when owner is set to vagrant" do
      before {
        allow(batch).to receive(:call) {''}
      }

      it "expects to have qstat called with -u vagrant" do
        batch.get_all(owner: 'vagrant')
        expect(batch).to have_received(:call).with('qstat',  '-r', '-xml', '-u', 'vagrant')
      end
    end
  end

  describe "#get_info_enqueued_job" do
    context "when the specific job is in the queue" do
      before {
        allow(batch).to receive(:call) { load_resource_file('spec/job/adapters/sge/output_examples/qstat_jr.xml') }
      }

      it "expects to receive the correct job info" do
        expect(batch.get_info_enqueued_job('88') ).to eq(job_from_qstat_jr)
      end
    end

    context "when the specific job is absent from the queue" do
      before {
        allow(batch).to receive(:call) { load_resource_file('spec/job/adapters/sge/output_examples/qstat_jr_missing.xml') }
      }

      it "expects to receive a job with status completed" do
        expect(batch.get_info_enqueued_job('1234') ).to eq(OodCore::Job::Info.new(id: '1234', status: :completed))
      end
    end

    context "when the subprocess call returns non-zero" do
      before {
        allow(batch).to receive(:call).and_raise(OodCore::Job::Adapters::Sge::Batch::Error)
      }

      it "does not catch errors that it should not" do
        expect{batch.get_info_enqueued_job('1234')}.to raise_error(OodCore::Job::Adapters::Sge::Batch::Error)
      end
    end

    context "when the job is running on multiple slots" do
      before {
        allow(batch).to receive(:call) { load_resource_file('spec/job/adapters/sge/output_examples/qstat_jr_multislot.xml') }
      }

      it "expects to receive the correct job info" do
        expect(batch.get_info_enqueued_job('942195') ).to eq(job_from_qstat_jr_mutlislot)
      end
    end

    context "when the scheduler is UGE" do
      before {
        allow(batch).to receive(:call) { load_resource_file('spec/job/adapters/sge/output_examples/uge_qstat_jr.xml') }
        # have to stub out time becuase the division to turn ms into s is a little flaky
        allow(Time).to receive(:now){ 1593900000 }
      }

      it "expects to receive the correct job info" do
        expect(batch.get_info_enqueued_job('748172') ).to eq(job_from_uge_qstat_jr)
      end

      it "expects to receive the correct ST_name" do 
        expect(batch.get_info_enqueued_job('748172').native[:ST_name] ).to eq("/export/uge/bin/lx-amd64/qsub -wd /home/johrstrom/ondemand/data/sys/dashboard/batch_connect/sys/jupyter/output/a4a46499-77d9-4334-bef2-71dd0a0857f6 -N jupyter_interactive -o /home/johrstrom/ondemand/data/sys/dashboard/batch_connect/sys/jupyter/output/a4a46499-77d9-4334-bef2-71dd0a0857f6/output.log -q ondemand -l h_rt=04:00:00 -P communitycluster -V -pe sm 11 hpcc ")
      end
    end
  end

  describe "customizing bin paths" do
    let(:script) { OodCore::Job::Script.new(content: "echo 'hi'") }

    context "when calling with normal config" do
      it "uses the correct command" do
        batch = described_class.new(bin: "/usr/bin", bin_overrides: {})
        allow(Open3).to receive(:capture3).and_return(["Your job 123", "", double("success?" => true)])

        OodCore::Job::Adapters::Sge.new(batch: batch).submit script
        expect(Open3).to have_received(:capture3).with(anything, "/usr/bin/qsub", any_args)
      end
    end

    context "when calling with overrides" do
      it "uses the correct command" do
        batch = described_class.new(bin: "/usr/bin", bin_overrides: {"qsub" => "/usr/local/bin/not_qsub"})
        allow(Open3).to receive(:capture3).and_return(["Your job 123", "", double("success?" => true)])

        OodCore::Job::Adapters::Sge.new(batch: batch).submit script
        expect(Open3).to have_received(:capture3).with(anything, "/usr/local/bin/not_qsub", any_args)
      end
    end
  end

  describe "setting submit_host" do 
    let(:script) { OodCore::Job::Script.new(content: "echo 'hi'") }

    context "when calling without submit_host" do 
      it "uses the correct command" do 
        batch = described_class.new(submit_host: "")
        allow(Open3).to receive(:capture3).and_return(["Your job 123", "", double("success?" => true)])

        OodCore::Job::Adapters::Sge.new(batch: batch).submit script
        expect(Open3).to have_received(:capture3).with(anything, "qsub", '-cwd', any_args)
      end
    end

    context "when calling with submit_host & strict_host_checking not specified" do 
      it "uses ssh wrapper & host checking defaults to yes" do 
        batch = described_class.new(submit_host: "owens.osc.edu")
        allow(Open3).to receive(:capture3).and_return(["Your job 123", "", double("success?" => true)])

        OodCore::Job::Adapters::Sge.new(batch: batch).submit script
        expect(Open3).to have_received(:capture3).with(anything, 'ssh', '-p', ENV['OOD_SSH_PORT'].nil? ? "22" : "#{ENV['OOD_SSH_PORT']}", '-o', 'BatchMode=yes', '-o', 'UserKnownHostsFile=/dev/null', '-o', 'StrictHostKeyChecking=yes', 'owens.osc.edu', 'qsub', '-cwd', any_args)
      end
    end

    context "when strict_host_checking = 'no' && submit_host specified" do
      it "sets host checking to no" do
        batch = described_class.new(submit_host: "owens.osc.edu", strict_host_checking: false)
        allow(Open3).to receive(:capture3).and_return(["Your job 123", "", double("success?" => true)])

        OodCore::Job::Adapters::Sge.new(batch: batch).submit script
        expect(Open3).to have_received(:capture3).with(anything, 'ssh', '-p', ENV['OOD_SSH_PORT'].nil? ? "22" : "#{ENV['OOD_SSH_PORT']}", '-o', 'BatchMode=yes', '-o', 'UserKnownHostsFile=/dev/null', '-o', 'StrictHostKeyChecking=no', 'owens.osc.edu', 'qsub', '-cwd', any_args)
      end
    end
  end
end
