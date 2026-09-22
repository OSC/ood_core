require "ood_core/job/adapters/kubernetes"

describe OodCore::Job::Adapters::Kubernetes do
  let(:batch) { double() }
  subject(:adapter) { described_class.new(batch) }

  it { is_expected.to respond_to(:submit).with(1).argument.and_keywords(:after, :afterok, :afternotok, :afterany) }
  it { is_expected.to respond_to(:info_all).with(0).arguments.and_keywords(:attrs) }
  it { is_expected.to respond_to(:info_where_owner).with(1).argument.and_keywords(:attrs) }
  it { is_expected.to respond_to(:info).with(1).argument }
  it { is_expected.to respond_to(:status).with(1).argument }
  it { is_expected.to respond_to(:hold).with(1).argument }
  it { is_expected.to respond_to(:release).with(1).argument }
  it { is_expected.to respond_to(:delete).with(1).argument }
  it { is_expected.to respond_to(:directive_prefix).with(0).arguments }

  it "does not support job arrays" do
    expect(adapter.supports_job_arrays?).to be_falsy
  end

  it "does not support hold" do
    expect { adapter.hold('123') }.to raise_error(NotImplementedError, 'subclass did not define #hold')
  end

  it "does not support release" do
    expect { adapter.release('123') }.to raise_error(NotImplementedError, 'subclass did not define #release')
  end

end
