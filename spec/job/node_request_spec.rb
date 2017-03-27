require "spec_helper"

describe OodCore::Job::NodeRequest do
  def build_nreq(opts = {})
    described_class.new(
      {
      }.merge opts
    )
  end

  # Subject
  subject { build_nreq }

  it { is_expected.to respond_to(:procs) }
  it { is_expected.to respond_to(:properties) }
  it { is_expected.to respond_to(:to_h) }

  describe "#procs" do
    subject { build_nreq(procs: double(to_i: 123)).procs }

    it { is_expected.to eq(123) }
  end

  describe "#properties" do
    context "when single object" do
      subject { build_nreq(properties: double(to_s: "prop")).properties }

      it { is_expected.to eq(["prop"]) }
    end

    context "when array of objects" do
      subject { build_nreq(properties: [double(to_s: "prop1"), double(to_s: "prop2")]).properties }

      it { is_expected.to eq(["prop1", "prop2"]) }
    end
  end

  describe "#to_h" do
    subject { build_nreq.to_h }

    it { is_expected.to be_a(Hash) }
    it { is_expected.to have_key(:procs) }
    it { is_expected.to have_key(:properties) }
  end

  describe "#==" do
    it "equals object with same attributes" do
      is_expected.to eq(build_nreq)
    end

    it "doesn't equal object with different attributes" do
      is_expected.not_to eq(build_nreq(procs: 10))
    end
  end
end
