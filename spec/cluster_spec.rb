require "spec_helper"

describe OodCore::Cluster do
  describe "#==" do
    context "with two clusters that only specify ids" do
      let(:owens) { OodCore::Cluster.new({ :id => "owens" }) }
      let(:oakley) { OodCore::Cluster.new({ :id => "oakley" }) }

      it "is not equal when comparing both clusters" do
        expect(owens).not_to eq(oakley)
      end

      it "is not equal when comparing to nil" do
        expect(owens).not_to eq(nil)
      end

      it "is equal when comparing single cluster with self" do
        expect(owens).to eq(owens)
      end

      it "is allowed since there are no restrictions" do
        expect(owens.allow?).to be true
      end

      it "does not support login" do
        expect(owens.login_allow?).to be false
      end

      it "does not support job submission" do
        expect(owens.job_allow?).to be false
      end

      it "returns same value for multiple invocations" do
        expect(owens.job_allow?).to be false
        expect(owens.job_allow?).to be false
        expect(owens.job_allow?).to be false
        expect(owens.login_allow?).to be false
        expect(owens.login_allow?).to be false
        expect(owens.login_allow?).to be false
        expect(owens.allow?).to be true
        expect(owens.allow?).to be true
        expect(owens.allow?).to be true
      end

      it "caches job_allow?" do
        expect(owens).to receive(:allow?).once
        2.times { owens.job_allow? }
      end

      it "caches login_allow?" do
        expect(owens).to receive(:allow?).once
        2.times { owens.login_allow? }
      end
    end
  end
end