require 'spec_helper'
require 'ood_core/acl/adapters/group'

describe OodCore::Acl::Adapters::Group do

  def build_group_acl(opts = {})
    OodCore::Acl::Factory.build_group(opts)
  end

  describe "#new" do
    context 'when nothing is provided' do
      it 'raises an error' do
        expect { subject }.to raise_error(ArgumentError)
      end
    end
  end

  # groups:
  # - "cluster_users"
  # - "other_users_of_the_cluster"
  # type: "whitelist"

  describe '#allow' do
    context 'when allowlist is provided' do
      subject { build_group_acl({ groups: ['group-a', 'group-x'], type: 'allowlist' }) }

      it 'allows users in that group' do
        allow_any_instance_of(OodSupport::User).to receive(:groups).and_return(['group-a', 'group-b'])
        expect(subject.allow?).to eql(true)
      end

      it 'blocks uses not in that group' do
        allow_any_instance_of(OodSupport::User).to receive(:groups).and_return(['group-c', 'group-d'])
        expect(subject.allow?).to eql(false)
      end
    end

    context 'when blocklist is provided' do
      subject { build_group_acl({ groups: ['group-a', 'group-x'], type: 'blocklist' }) }

      it 'blocks users in that group' do
        allow_any_instance_of(OodSupport::User).to receive(:groups).and_return(['group-a', 'group-b'])
        expect(subject.allow?).to eql(false)
      end

      it 'allows uses not in that group' do
        allow_any_instance_of(OodSupport::User).to receive(:groups).and_return(['group-c', 'group-d'])
        expect(subject.allow?).to eql(true)
      end
    end

    context 'when whitelist is provided' do
      subject { build_group_acl({ groups: ['group-a', 'group-x'], type: 'whitelist' }) }

      it 'allows users in that group' do
        allow_any_instance_of(OodSupport::User).to receive(:groups).and_return(['group-a', 'group-b'])
        expect(subject.allow?).to eql(true)
      end

      it 'blocks uses not in that group' do
        allow_any_instance_of(OodSupport::User).to receive(:groups).and_return(['group-c', 'group-d'])
        expect(subject.allow?).to eql(false)
      end
    end

    context 'when blacklist is provided' do
      subject { build_group_acl({ groups: ['group-a', 'group-x'], type: 'blacklist' }) }

      it 'blocks users in that group' do
        allow_any_instance_of(OodSupport::User).to receive(:groups).and_return(['group-a', 'group-b'])
        expect(subject.allow?).to eql(false)
      end

      it 'allows uses not in that group' do
        allow_any_instance_of(OodSupport::User).to receive(:groups).and_return(['group-c', 'group-d'])
        expect(subject.allow?).to eql(true)
      end
    end
  end
end
