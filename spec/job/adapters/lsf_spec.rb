
require "spec_helper"
require "ood_core/job/adapters/lsf"

describe OodCore::Job::Adapters::Lsf do
  let(:batch) { double() }
  subject(:adapter) { described_class.new(batch: batch) }

  it { is_expected.to respond_to(:submit).with(1).argument.and_keywords(:after, :afterok, :afternotok, :afterany) }
  it { is_expected.to respond_to(:info_all).with(0).arguments }
  it { is_expected.to respond_to(:info).with(1).argument }
  it { is_expected.to respond_to(:status).with(1).argument }
  it { is_expected.to respond_to(:hold).with(1).argument }
  it { is_expected.to respond_to(:release).with(1).argument }
  it { is_expected.to respond_to(:delete).with(1).argument }

  describe "#submit" do
    def build_script(opts = {})
      OodCore::Job::Script.new(
        {
          content: content
        }.merge opts
      )
    end

    # override existing batch var so when adapter is instantiated
    # we get an adapter with this batch object
    let(:batch) { 
      double(submit_string: "job.123")
    }
    let(:content) { "my batch script" }

    context "with script" do
      before { adapter.submit(build_script()) }
      it { expect(batch).to have_received(:submit_string).with(content, args: [], env: {}) }
    end

    context "when OodCore::Job::Adapters::Lsf::Batch::Error is raised" do
      before { expect(batch).to receive(:submit_string).and_raise(OodCore::Job::Adapters::Lsf::Batch::Error) }

      it "raises OodCore::JobAdapterError" do
        expect { adapter.submit(build_script()) }.to raise_error(OodCore::JobAdapterError)
      end
    end
  end

  # TODO: tests to add:
  # queued job
  # running job
  # when can't find job, status complete
  # when can find job and status is EXIT or DONE, status complete
  describe "#status and #info" do
    let(:year) { 2017 }
    before { allow(Time).to receive(:now)  { Time.local(year, 04, 01) } }

    # TODO: do we create a complex mock?
    let(:batch) { double(get_jobs: [job_hash], get_job: job_hash) }
    let(:start_time) { Time.local(year, 3, 31, 14, 46, 44) }

    #FIXME: using the filters to select specific fields, we can ensure that this doesn't change
    #as LSF::Batch support more attributes
    let(:job_hash) {
      {
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
      }
    }

    let(:expected_info){
      OodCore::Job::Info.new(
            :id=>"542935",
            :status=>OodCore::Job::Status.new(state: :running),

            # TODO: add tests and implement getting the NodeInfo objects
            # from the possible exec_host string list i.e. 15*compute076
            :allocated_nodes=>[OodCore::Job::NodeInfo.new(name: "compute013", procs: 1)],

            :submit_host=> job_hash[:from_host],
            :job_name=>job_hash[:name],
            :job_owner=>job_hash[:user],
            :accounting_id=>job_hash[:project],

            :procs=>1,

            :queue_name=>job_hash[:queue],

            # estimated run time
            :wallclock_time=>Time.now - start_time,
            # TODO: job_hash[:cpu_used] converted to proper format
            :cpu_time=>0,
            :submission_time=>Time.local(year, 3, 31, 14, 46, 42),
            :dispatch_time=>start_time,
            :native=>job_hash
        )
    }

    describe "#status" do
      it "returns running status" do
        expect(adapter.status("542935")).to eq(OodCore::Job::Status.new(state: :running))
      end
    end

    describe "#info" do
      it "returns running status with info attrs mapped" do
        expect(adapter.info("542935")).to eq(expected_info)
      end

      context "when can't find job" do
        let(:batch) { double(get_job: nil) }

        it "returns completed OodCore::Job::Info object" do
          expect(adapter.info("542935")).to eq(OodCore::Job::Info.new(id: "542935", status: :completed))
        end
      end
    end

    describe "#info_all" do
      it "returns array of info objects" do
        expect(adapter.info_all).to eq([expected_info])
      end
    end

    describe "#info_where_owner" do
      it "handles 0 owners" do
        expect(adapter.info_where_owner([])).to eq([])
        expect(adapter.info_where_owner(nil)).to eq([])
      end

      it "optimizes 1 owner" do
        expect(batch).to receive(:get_jobs_for_user).with("efranz").and_return([])
        adapter.info_where_owner("efranz")
      end

      it "optimizes 1 owner in array" do
        expect(batch).to receive(:get_jobs_for_user).with("efranz").and_return([])
        adapter.info_where_owner(["efranz"])
      end

      # we don't optimize multiple owners because LSF's bjobs doesn't accept -u with multiple users
      it "doesn't optimize multiple owners" do
        expect(batch).to receive(:get_jobs_for_user).exactly(0).times
        expect(adapter.info_where_owner(["efranz", "jnicklas"])).to eq([expected_info])
      end
    end
  end

  describe ".build_lsf" do
    it "builds an adapter for config" do
      adapter = OodCore::Job::Factory.build_lsf(
        adapter: "lsf",
        bindir: "/opt/lsf/8.3/bin",
        libdir: "/opt/lsf/8.3/lib",
        envdir: "/opt/lsf/conf",
        serverdir: "/opt/lsf/8.3/etc"
      )

      expect(adapter.batch.default_env).to eq(
        {
          "LSF_BINDIR" => "/opt/lsf/8.3/bin",
          "LSF_LIBDIR" => "/opt/lsf/8.3/lib",
          "LSF_ENVDIR" =>"/opt/lsf/conf",
          "LSF_SERVERDIR" =>"/opt/lsf/8.3/etc"
        }
      )
    end
  end
end
