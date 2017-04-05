require "spec_helper"

describe OodCore::Job::Adapter do
  it { is_expected.to respond_to(:submit).with(1).argument.and_keywords(:after, :afterok, :afternotok, :afterany) }
  it { is_expected.to respond_to(:info_all).with(0).arguments }
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
