require "spec_helper"

describe OodCore::Job::Script do
  def build_script(opts = {})
    described_class.new(
      **{
        content: content
      }.merge(opts)
    )
  end

  # Required arguments
  let(:content) { "my script content" }

  # Subject
  subject { build_script }

  it { is_expected.to respond_to(:content) }
  it { is_expected.to respond_to(:args) }
  it { is_expected.to respond_to(:submit_as_hold) }
  it { is_expected.to respond_to(:rerunnable) }
  it { is_expected.to respond_to(:job_environment) }
  it { is_expected.to respond_to(:workdir) }
  it { is_expected.to respond_to(:email) }
  it { is_expected.to respond_to(:email_on_started) }
  it { is_expected.to respond_to(:email_on_terminated) }
  it { is_expected.to respond_to(:job_name) }
  it { is_expected.to respond_to(:shell_path) }
  it { is_expected.to respond_to(:input_path) }
  it { is_expected.to respond_to(:output_path) }
  it { is_expected.to respond_to(:error_path) }
  it { is_expected.to respond_to(:reservation_id) }
  it { is_expected.to respond_to(:queue_name) }
  it { is_expected.to respond_to(:priority) }
  it { is_expected.to respond_to(:start_time) }
  it { is_expected.to respond_to(:wall_time) }
  it { is_expected.to respond_to(:accounting_id) }
  it { is_expected.to respond_to(:job_array_request) }
  it { is_expected.to respond_to(:qos) }
  it { is_expected.to respond_to(:gpus_per_node) }
  it { is_expected.to respond_to(:native) }
  it { is_expected.to respond_to(:to_h) }
  it { is_expected.to respond_to(:copy_environment) }

  describe '.new' do
    context "when :context not defined" do
      subject { described_class.new }

      it "raises ArgumentError" do
        expect { subject }.to raise_error(ArgumentError)
      end
    end
  end

  describe "#content" do
    subject { build_script(content: double(to_s: "my content")).content }

    it { is_expected.to eq("my content") }
  end

  describe "#args" do
    subject { build_script(args: [double(to_s: "arg1"), double(to_s: "arg2")]).args }

    it { is_expected.to eq(["arg1", "arg2"]) }
  end

  describe "#submit_as_hold" do
    subject { build_script(submit_as_hold: false).submit_as_hold }

    it { is_expected.to eq(false) }
  end

  describe "#rerunnable" do
    subject { build_script(rerunnable: false).rerunnable }

    it { is_expected.to eq(false) }
  end

  describe "#job_environment" do
    subject { build_script(job_environment: {double(to_s: "key") => double(to_s: "value")}).job_environment }

    it { is_expected.to eq({"key" => "value"}) }
  end

  describe "#workdir" do
    subject { build_script(workdir: double(to_s: "/path/to/workdir")).workdir }

    it { is_expected.to eq(Pathname.new("/path/to/workdir")) }
  end

  describe "#email" do
    context "when single email" do
      subject { build_script(email: double(to_s: "email")).email }

      it { is_expected.to eq(["email"]) }
    end

    context "when array of emails" do
      subject { build_script(email: [double(to_s: "email1"), double(to_s: "email2")]).email }

      it { is_expected.to eq(["email1", "email2"]) }
    end
  end

  describe "#email_on_started" do
    subject { build_script(email_on_started: false).email_on_started }

    it { is_expected.to eq(false) }
  end

  describe "#email_on_terminated" do
    subject { build_script(email_on_terminated: false).email_on_terminated }

    it { is_expected.to eq(false) }
  end

  describe "#job_name" do
    subject { build_script(job_name: double(to_s: "my_job")).job_name }

    it { is_expected.to eq("my_job") }
  end

  describe "#shell_path" do
    subject { build_script(shell_path: double(to_s: "/path/to/shell")).shell_path }

    it { is_expected.to eq(Pathname.new("/path/to/shell")) }
  end

  describe "#input_path" do
    subject { build_script(input_path: double(to_s: "/path/to/input")).input_path }

    it { is_expected.to eq(Pathname.new("/path/to/input")) }
  end

  describe "#output_path" do
    subject { build_script(output_path: double(to_s: "/path/to/output")).output_path }

    it { is_expected.to eq(Pathname.new("/path/to/output")) }
  end

  describe "#error_path" do
    subject { build_script(error_path: double(to_s: "/path/to/error")).error_path }

    it { is_expected.to eq(Pathname.new("/path/to/error")) }
  end

  describe "#reservation_id" do
    subject { build_script(reservation_id: double(to_s: "my_rsv")).reservation_id }

    it { is_expected.to eq("my_rsv") }
  end

  describe "#queue_name" do
    subject { build_script(queue_name: double(to_s: "my_queue")).queue_name }

    it { is_expected.to eq("my_queue") }
  end

  describe "#priority" do
    subject { build_script(priority: double(to_i: 123)).priority }

    it { is_expected.to eq(123) }
  end

  describe "#start_time" do
    subject { build_script(start_time: double(to_i: 123)).start_time }

    it { is_expected.to eq(Time.at(123)) }
  end

  describe "#wall_time" do
    subject { build_script(wall_time: double(to_i: 123)).wall_time }

    it { is_expected.to eq(123) }
  end

  describe "#accounting_id" do
    subject { build_script(accounting_id: double(to_s: "my_account")).accounting_id }

    it { is_expected.to eq("my_account") }
  end

  describe "#qos" do
    subject { build_script(qos: double(to_s: "test")).qos }

    it { is_expected.to eq("test") }
  end

  describe "#gpus_per_node" do
    subject { build_script(gpus_per_node: double(to_i: 1)).gpus_per_node }

    it { is_expected.to eq(1) }
  end

  describe "#native" do
    subject { build_script(native: "native").native }

    it { is_expected.to eq("native") }
  end

  describe "#to_h" do
    subject { build_script.to_h }

    it { is_expected.to be_a(Hash) }
    it { is_expected.to have_key(:content) }
    it { is_expected.to have_key(:args) }
    it { is_expected.to have_key(:submit_as_hold) }
    it { is_expected.to have_key(:rerunnable) }
    it { is_expected.to have_key(:job_environment) }
    it { is_expected.to have_key(:workdir) }
    it { is_expected.to have_key(:email) }
    it { is_expected.to have_key(:email_on_started) }
    it { is_expected.to have_key(:email_on_terminated) }
    it { is_expected.to have_key(:job_name) }
    it { is_expected.to have_key(:shell_path) }
    it { is_expected.to have_key(:input_path) }
    it { is_expected.to have_key(:output_path) }
    it { is_expected.to have_key(:error_path) }
    it { is_expected.to have_key(:reservation_id) }
    it { is_expected.to have_key(:queue_name) }
    it { is_expected.to have_key(:priority) }
    it { is_expected.to have_key(:start_time) }
    it { is_expected.to have_key(:wall_time) }
    it { is_expected.to have_key(:accounting_id) }
    it { is_expected.to have_key(:job_array_request) }
    it { is_expected.to have_key(:qos) }
    it { is_expected.to have_key(:gpus_per_node) }
    it { is_expected.to have_key(:native) }
    it { is_expected.to have_key(:copy_environment) }
  end

  describe "#==" do
    it "equals object with same attributes" do
      is_expected.to eq(build_script)
    end

    it "doesn't equal object with different attributes" do
      is_expected.not_to eq(build_script(priority: 123))
    end
  end

  describe "#copy_environment" do
    context "when default constructed" do
      subject { build_script().copy_environment }

      it { is_expected.to eq(nil) }
    end

    context "when set to be true" do
      subject { build_script(copy_environment: true).copy_environment }

      it { is_expected.to eq(true) }
    end
  end
end
