require "spec_helper"
require "ood_core/job/adapters/sge"
require "ood_core/job/adapters/sge/batch"

def load_resource_file(file_name)
  File.open(file_name, 'r') { |f| f.read }
end

describe OodCore::Job::Adapters::Sge::Batch do
  subject(:batch) {described_class.new({:conf => '', :cluster => '', :bin => ''})}
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
      :native => {}
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
      :native => {}
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
      :native => {}
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
      :native => {}
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
      :native => {},
      :procs => 1,
      :queue_name => nil,
      :status => :running,
      :submission_time => Time.at(1541444183),
      :submit_host => nil,
      :wallclock_limit => 86400,
      :wallclock_time => Time.now.to_i - 1541444223
    )
  }

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
        allow(batch).to receive(:call).and_raise(StandardError)
      }

      it "does not catch errors that it should not" do
        expect{batch.get_info_enqueued_job('1234')}.to raise_error(StandardError)
      end
    end
  end
end



