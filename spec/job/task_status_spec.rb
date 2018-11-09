require "spec_helper"

describe OodCore::Job::TaskStatus do
  def build_info(opts = {})
    described_class.new(
      {
        id: id,
        status: status
      }.merge opts
    )
  end

  # Required arguments
  let(:id)     { "my_id" }
  let(:status) { OodCore::Job::Status.new(state: :running) }

  # Subject
  subject { build_info }
  it { is_expected.to respond_to(:id) }
  it { is_expected.to respond_to(:status) }
  it { is_expected.to respond_to(:to_h) }

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
end