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

      it 'has default for batch_connect_ssh_allow?' do
        expect(owens.batch_connect_ssh_allow?).to be_nil
      end

      it 'can enable batch_connect_ssh_allow?' do
        owens = OodCore::Cluster.new({id: "owens", batch_connect: { ssh_allow: true } })
        expect(owens.batch_connect_ssh_allow?).to be true
      end

      it 'can disable batch_connect_ssh_allow?' do
        owens = OodCore::Cluster.new({id: "owens", batch_connect: { ssh_allow: false } })
        expect(owens.batch_connect_ssh_allow?).to be false
      end

      it "caches batch_connect_ssh_allow?" do
        expect(owens).to receive(:batch_connect_config).once
        2.times { owens.batch_connect_ssh_allow? }
      end
    end
  end

  context "with cluster with acls" do
    let(:owens) { OodCore::Cluster.new({ id: "owens", acls: [{adapter: 'group', groups: ['foo'], type: 'whitelist'}]}) }

    it "blocks users not in specified group" do
      allow_any_instance_of(OodSupport::User).to receive(:groups).and_return(['bar'])

      expect(owens.allow?).to be false
    end

    it "allows users in specified group" do
      allow_any_instance_of(OodSupport::User).to receive(:groups).and_return(['foo'])

      expect(owens.allow?).to be true
    end

    it "only checks group membership once" do
      expect_any_instance_of(OodSupport::User).to receive(:groups).once.and_return(['foo'])

      owens.allow?
      owens.allow?
      owens.allow?
    end
  end
end