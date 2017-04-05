require "spec_helper"

describe OodCore::Job::NodeInfo do
  def build_ninfo(opts = {})
    described_class.new(
      {
        name: name,
        procs: procs
      }.merge opts
    )
  end

  # Required arguments
  let(:name)  { "my_node" }
  let(:procs) { 123 }

  # Subject
  subject { build_ninfo }

  it { is_expected.to respond_to(:name) }
  it { is_expected.to respond_to(:procs) }
  it { is_expected.to respond_to(:to_h) }

  describe ".new" do
    context "when :name not defined" do
      subject { described_class.new(procs: procs) }

      it "raises ArgumentError" do
        expect { subject }.to raise_error(ArgumentError)
      end
    end
  end

  describe "#name" do
    subject { build_ninfo(name: double(to_s: "my_node")).name }

    it { is_expected.to eq("my_node") }
  end

  describe "#procs" do
    subject { build_ninfo(procs: double(to_i: 123)).procs }

    it { is_expected.to eq(123) }
  end

  describe "#to_h" do
    subject { build_ninfo.to_h }

    it { is_expected.to be_a(Hash) }
    it { is_expected.to have_key(:name) }
    it { is_expected.to have_key(:procs) }
  end

  describe "#==" do
    it "equals object with same attributes" do
      is_expected.to eq(build_ninfo)
    end

    it "doesn't equal object with different attributes" do
      is_expected.not_to eq(build_ninfo(procs: 10))
    end
  end
end
