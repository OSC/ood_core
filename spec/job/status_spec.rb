require "spec_helper"

describe OodCore::Job::Status do
  states =
    %i(queued queued_held running suspended undetermined completed)

  subject { described_class.new(state: :running) }

  it { is_expected.to respond_to(:state) }
  it { is_expected.to respond_to(:to_sym) }
  it { is_expected.to respond_to(:to_s) }
  states.each do |state|
    it { is_expected.to respond_to("#{state}?") }
  end

  describe ".new" do
    context "when :state not defined" do
      subject { described_class.new }

      it "raises ArgumentError" do
        expect { subject }.to raise_error(ArgumentError)
      end
    end

    context 'when :state is invalid' do
      subject { described_class.new(state: :invalid_state) }

      it 'raises OodCore::UnknownStateAttribute' do
        expect { subject }.to raise_error(OodCore::UnknownStateAttribute)
      end
    end
  end

  describe "#state" do
    subject { described_class.new(state: double(to_sym: :running)).state }

    it { is_expected.to eq(:running) }
  end

  describe "#to_sym" do
    subject { described_class.new(state: double(to_sym: :running)).to_sym }

    it { is_expected.to eq(:running) }
  end

  describe "#to_s" do
    subject { described_class.new(state: double(to_sym: :running)).to_s }

    it { is_expected.to eq("running") }
  end

  states.each do |state|
    describe "##{state}?" do
      context "when :#{state}" do
        subject { described_class.new(state: state).send("#{state}?") }

        it { is_expected.to be_truthy }
      end

      states.select { |s| s != state }.each do |diff_state|
        context "when :#{diff_state}" do
          subject { described_class.new(state: diff_state).send("#{state}?") }

          it { is_expected.to be_falsey }
        end
      end
    end
  end

  describe "#==" do
    it "equals object with same state" do
      expect(OodCore::Job::Status.new(state: :running)).to eq(OodCore::Job::Status.new(state: :running))
    end

    it "doesn't equal object with different state" do
      expect(OodCore::Job::Status.new(state: :running)).not_to eq(OodCore::Job::Status.new(state: :queued))
    end

    it "equals String or symbol with same state representation" do
      expect(OodCore::Job::Status.new(state: :running)).to eq("running")
      expect(OodCore::Job::Status.new(state: :running)).to eq(:running)
    end
  end
end
