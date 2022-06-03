require "spec_helper"

describe OodCore::Job::Info do
  def build_info(opts = {})
    described_class.new(
      **{
        id: id,
        status: status
      }.merge(opts)
    )
  end

  # Required arguments
  let(:id)     { "my_id" }
  let(:status) { OodCore::Job::Status.new(state: :running) }

  # Subject
  subject { build_info }

  it { is_expected.to respond_to(:id) }
  it { is_expected.to respond_to(:status) }
  it { is_expected.to respond_to(:allocated_nodes) }
  it { is_expected.to respond_to(:submit_host) }
  it { is_expected.to respond_to(:job_name) }
  it { is_expected.to respond_to(:job_owner) }
  it { is_expected.to respond_to(:accounting_id) }
  it { is_expected.to respond_to(:procs) }
  it { is_expected.to respond_to(:queue_name) }
  it { is_expected.to respond_to(:wallclock_time) }
  it { is_expected.to respond_to(:wallclock_limit) }
  it { is_expected.to respond_to(:cpu_time) }
  it { is_expected.to respond_to(:submission_time) }
  it { is_expected.to respond_to(:dispatch_time) }
  it { is_expected.to respond_to(:native) }
  it { is_expected.to respond_to(:gpus) }
  it { is_expected.to respond_to(:to_h) }
  it { is_expected.to respond_to(:tasks) }

  describe ".new" do
    context "when :id not defined" do
      subject { described_class.new(status: status) }

      it "raises ArgumentError" do
        expect { subject }.to raise_error(ArgumentError)
      end
    end

    context "when :status not defined" do
      subject { described_class.new(id: id) }

      it "raises ArgumentError" do
        expect { subject }.to raise_error(ArgumentError)
      end
    end
  end

  describe "#id" do
    subject { build_info(id: double(to_s: "my_id")).id }

    it { is_expected.to eq("my_id") }
  end

  describe "#status" do
    subject { build_info(status: double(to_sym: :running)).status }

    it { is_expected.to eq(OodCore::Job::Status.new(state: :running)) }
  end

  describe "#allocated_nodes" do
    subject { build_info(
      allocated_nodes: [
        double(to_h: {name: "node1", procs: 20}),
        double(to_h: {name: "node2", procs: 40})
      ]
    ).allocated_nodes }

    it { is_expected.to eq([
      OodCore::Job::NodeInfo.new(name: "node1", procs: 20),
      OodCore::Job::NodeInfo.new(name: "node2", procs: 40)
    ])}
  end

  describe "#submit_host" do
    subject { build_info(submit_host: double(to_s: "my_submit_host")).submit_host }

    it { is_expected.to eq("my_submit_host") }
  end

  describe "#job_name" do
    subject { build_info(job_name: double(to_s: "my_job_name")).job_name }

    it { is_expected.to eq("my_job_name") }
  end

  describe "#job_owner" do
    subject { build_info(job_owner: double(to_s: "my_job_owner")).job_owner }

    it { is_expected.to eq("my_job_owner") }
  end

  describe "#accounting_id" do
    subject { build_info(accounting_id: double(to_s: "my_account_id")).accounting_id }

    it { is_expected.to eq("my_account_id") }
  end

  describe "#procs" do
    subject { build_info(procs: double(to_i: 123)).procs }

    it { is_expected.to eq(123) }
  end

  describe "#queue_name" do
    subject { build_info(queue_name: double(to_s: "my_queue")).queue_name }

    it { is_expected.to eq("my_queue") }
  end

  describe "#wallclock_time" do
    subject { build_info(wallclock_time: double(to_i: 12345)).wallclock_time }

    it { is_expected.to eq(12345) }
  end

  describe "#wallclock_limit" do
    subject { build_info(wallclock_limit: double(to_i: 12345)).wallclock_limit }

    it { is_expected.to eq(12345) }
  end

  describe "#cpu_time" do
    subject { build_info(cpu_time: double(to_i: 12345)).cpu_time }

    it { is_expected.to eq(12345) }
  end

  describe "#submission_time" do
    subject { build_info(submission_time: double(to_i: 12345)).submission_time }

    it { is_expected.to eq(Time.at(12345)) }
  end

  describe "#dispatch_time" do
    subject { build_info(dispatch_time: double(to_i: 12345)).dispatch_time }

    it { is_expected.to eq(Time.at(12345)) }
  end

  describe "#native" do
    subject { build_info(native: "native").native }

    it { is_expected.to eq("native") }
  end

  describe "#gpus" do
    subject { build_info(native: "gpus").native }

    it { is_expected.to eq("gpus") }
  end

  describe "#to_h" do
    subject { build_info.to_h }

    it { is_expected.to be_a(Hash) }
    it { is_expected.to have_key(:id) }
    it { is_expected.to have_key(:status) }
    it { is_expected.to have_key(:allocated_nodes) }
    it { is_expected.to have_key(:submit_host) }
    it { is_expected.to have_key(:job_name) }
    it { is_expected.to have_key(:job_owner) }
    it { is_expected.to have_key(:accounting_id) }
    it { is_expected.to have_key(:procs) }
    it { is_expected.to have_key(:queue_name) }
    it { is_expected.to have_key(:wallclock_time) }
    it { is_expected.to have_key(:wallclock_limit) }
    it { is_expected.to have_key(:cpu_time) }
    it { is_expected.to have_key(:submission_time) }
    it { is_expected.to have_key(:dispatch_time) }
    it { is_expected.to have_key(:native) }
    it { is_expected.to have_key(:gpus) }
  end

  describe "#==" do
    it "equals object with same attributes" do
      is_expected.to eq(build_info)
    end

    it "doesn't equal object with different attributes" do
      is_expected.not_to eq(build_info(procs: 10))
    end
  end

  describe "#tasks" do
    context "when built with an empty tasks" do
      subject {build_info(tasks: [])}

      it { is_expected.to eq(build_info)}
    end

    context "elements of :tasks are converted to OodCore::Job::Task" do
      subject { build_info(tasks: [{:id => id, :status => :running}]).tasks.first }

      it { is_expected.to be_a(OodCore::Job::Task) }
    end

    context "when multiple :tasks exist and one is running" do
      subject { build_info(
          tasks: [
            {:id => 1, :status => :running},
            {:id => 2, :status => :queued}
          ]
        ).status
      }

      it { is_expected.to eq(OodCore::Job::Status.new(state: :running)) }
    end
  end
end
