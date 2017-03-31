require "spec_helper"
require "ood_core/job/adapters/lsf"

describe OodCore::Job::Adapters::Lsf do
  # Required arguments
  let(:config) { {} }

  # Subject
  subject(:adapter) { described_class.new(config) }

  it { is_expected.to respond_to(:submit).with(0).arguments.and_keywords(:script, :after, :afterok, :afternotok, :afterany) }
  it { is_expected.to respond_to(:info).with(0).arguments.and_keywords(:id) }
  it { is_expected.to respond_to(:status).with(0).arguments.and_keywords(:id) }
  it { is_expected.to respond_to(:hold).with(0).arguments.and_keywords(:id) }
  it { is_expected.to respond_to(:release).with(0).arguments.and_keywords(:id) }
  it { is_expected.to respond_to(:delete).with(0).arguments.and_keywords(:id) }

  #TODO: mixing tests for lsf batch; lets move this to module
  describe "Batch#parse_bsub_output" do
    subject(:batch) { OodCore::Job::Adapters::Lsf::Batch.new() }

    # parse bsubmit output
    it "should correctly parse bjobs output" do
      expect(batch.parse_bsub_output "Job <542935> is submitted to queue <short>.\n").to eq "542935"
    end
  end

  # parse_bjobs_output
  # TODO:
end
