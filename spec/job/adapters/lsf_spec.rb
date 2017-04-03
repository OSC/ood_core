require "spec_helper"
require "ood_core/job/adapters/lsf"

describe OodCore::Job::Adapters::Lsf do
  let(:batch) { double() }
  subject(:adapter) { described_class.new(batch: batch) }

  it { is_expected.to respond_to(:submit).with(0).arguments.and_keywords(:script, :after, :afterok, :afternotok, :afterany) }
  it { is_expected.to respond_to(:info).with(0).arguments.and_keywords(:id) }
  it { is_expected.to respond_to(:status).with(0).arguments.and_keywords(:id) }
  it { is_expected.to respond_to(:hold).with(0).arguments.and_keywords(:id) }
  it { is_expected.to respond_to(:release).with(0).arguments.and_keywords(:id) }
  it { is_expected.to respond_to(:delete).with(0).arguments.and_keywords(:id) }

  describe "#submit" do
    def build_script(opts = {})
      OodCore::Job::Script.new(
        {
          content: content
        }.merge opts
      )
    end

    # override existing batch var so when adapter is instantiated
    # we get an adapter with this batch object
    let(:batch) { double(submit_string: "job.123") }
    let(:content) { "my batch script" }

    context "with script" do
      before { adapter.submit(script: build_script()) }

      it { expect(batch).to have_received(:submit_string).with(content, args: [], env: {}) }
    end
  end
end
