require "spec_helper"

describe OodCore::Job::Adapter do
  # Subject
  subject(:adapter) { described_class.new }

  it { is_expected.to respond_to(:submit).with(1).argument.and_keywords(:after, :afterok, :afternotok, :afterany) }
  it { is_expected.to respond_to(:info_all).with(0).arguments.and_keywords(:attrs) }
  it { is_expected.to respond_to(:info_where_owner).with(1).argument.and_keywords(:attrs) }
  it { is_expected.to respond_to(:info).with(1).argument }
  it { is_expected.to respond_to(:status).with(1).argument }
  it { is_expected.to respond_to(:hold).with(1).argument }
  it { is_expected.to respond_to(:release).with(1).argument }
  it { is_expected.to respond_to(:delete).with(1).argument }

  describe "#submit" do
    context "when script not defined" do
      it "raises ArgumentError" do
        expect { subject.submit }.to raise_error(ArgumentError)
      end
    end

    context "when valid arguments" do
      it "raises NotImplementedError" do
        expect { subject.submit "script" }.to raise_error(NotImplementedError)
      end
    end
  end

  describe "#info_all" do
    it "raises NotImplementedError" do
      expect { subject.info_all }.to raise_error(NotImplementedError)
    end
  end

  describe "#info_where_owner" do
    let(:bob_job) { double("bob", job_owner: "bob") }
    let(:sam_job) { double("sam", job_owner: "sam") }
    let(:jon_job) { double("jon", job_owner: "jon") }

    subject { adapter.info_where_owner(owner) }

    before { allow(adapter).to receive(:info_all) { [bob_job, sam_job, bob_job, jon_job] } }

    context "when no jobs with specified owner" do
      let(:owner) { "nobody" }

      it { is_expected.to eq([]) }
    end

    context "when jobs exist for specified owner" do
      let(:owner) { "bob" }

      it { is_expected.to eq([bob_job, bob_job]) }
    end

    context "when more than one owner specified" do
      let(:owner) { ["bob", "sam"] }

      it { is_expected.to eq([bob_job, sam_job, bob_job]) }
    end
  end

  describe "#info_where_owner(owner, attrs:)" do
    let(:bob_job) { double("bob", job_owner: "bob") }

    context "when attrs set to []" do
      it "calls info_all with job_owner as required attr" do
        expect(adapter).to receive(:info_all).with(:attrs => [:job_owner]) { [bob_job, bob_job] }
        adapter.info_where_owner_each("bob", attrs: []).to_a
      end
    end

    context "when attrs not set" do
      it "calls info_all with attrs: nil" do
        expect(adapter).to receive(:info_all).with(:attrs => nil) { [bob_job, bob_job] }
        adapter.info_where_owner_each("bob").to_a
      end
    end
  end

  describe "#info_where_owner_each" do
    let(:bob_job) { double("bob", job_owner: "bob") }
    let(:sam_job) { double("sam", job_owner: "sam") }
    before { allow(adapter).to receive(:info_all) { [bob_job, sam_job, bob_job] } }

    it "returns only jobs owned by specified user" do
      expect(adapter.info_where_owner_each("bob").count).to eq(2)
      expect(adapter.info_where_owner_each("sam").count).to eq(1)
    end

    it "returns same jobs as info_where_owner" do
      expect(adapter.info_where_owner_each("bob").to_a).to eq(adapter.info_where_owner("bob"))
      expect(adapter.info_where_owner_each("sam").to_a).to eq(adapter.info_where_owner("sam"))
    end

    it "calls info_where_owner with same arguments" do
      expect(adapter).to receive(:info_where_owner).with("bob", :attrs => []) { [bob_job, bob_job] }
      adapter.info_where_owner_each("bob", attrs: []).to_a
    end
  end

  describe "#info_all_each" do
    let(:bob_job) { double("bob", job_owner: "bob") }
    let(:sam_job) { double("sam", job_owner: "sam") }
    before { allow(adapter).to receive(:info_all) { [bob_job, sam_job, bob_job] } }

    it "returns same jobs as info_all" do
      expect(adapter.info_all_each.to_a).to eq(adapter.info_all)
    end

    it "calls info_all with same arguments" do
      expect(adapter).to receive(:info_all).with(:attrs => [])

      adapter.info_all_each(attrs: []).to_a
    end
  end

  describe "#info" do
    context "when id not defined" do
      it "raises ArgumentError" do
        expect { subject.info }.to raise_error(ArgumentError)
      end
    end

    it "raises NotImplementedError" do
      expect { subject.info "id" }.to raise_error(NotImplementedError)
    end
  end

  describe "#status" do
    context "when id not defined" do
      it "raises ArgumentError" do
        expect { subject.status }.to raise_error(ArgumentError)
      end
    end

    context "when valid arguments" do
      it "raises NotImplementedError" do
        expect { subject.status "id" }.to raise_error(NotImplementedError)
      end
    end
  end

  describe "#hold" do
    context "when id not defined" do
      it "raises ArgumentError" do
        expect { subject.hold }.to raise_error(ArgumentError)
      end
    end

    context "when valid arguments" do
      it "raises NotImplementedError" do
        expect { subject.hold "id" }.to raise_error(NotImplementedError)
      end
    end
  end

  describe "#release" do
    context "when id not defined" do
      it "raises ArgumentError" do
        expect { subject.release }.to raise_error(ArgumentError)
      end
    end

    context "when valid arguments" do
      it "raises NotImplementedError" do
        expect { subject.release "id" }.to raise_error(NotImplementedError)
      end
    end
  end

  describe "#delete" do
    context "when id not defined" do
      it "raises ArgumentError" do
        expect { subject.delete }.to raise_error(ArgumentError)
      end
    end

    context "when valid arguments" do
      it "raises NotImplementedError" do
        expect { subject.delete "id" }.to raise_error(NotImplementedError)
      end
    end
  end
end
