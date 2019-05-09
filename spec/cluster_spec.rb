require "spec_helper"

describe OodCore::Cluster do
  describe "#==" do
    context "when compared with another cluster" do
      let(:owens) { OodCore::Cluster.new({ :id => "owens" }) }
      let(:oakley) { OodCore::Cluster.new({ :id => "oakley" }) }

      it "is equal" do
        expect(owens).not_to eq(oakley)
      end
    end

    context "when compared with itself" do
      let(:owens) { OodCore::Cluster.new({ :id => "owens" }) }

      it "is equal" do
        expect(owens).to eq(owens)
      end
    end

    context "when compared with nil" do
      let(:owens) { OodCore::Cluster.new({ :id => "owens" }) }

      it "is not equal" do
        expect(owens).not_to eq(nil)
      end
    end
  end
end