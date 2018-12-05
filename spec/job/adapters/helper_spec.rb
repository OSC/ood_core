require "spec_helper"
require "ood_core/job/adapters/helper"

describe OodCore::Job::Adapters::Helper do
  subject(:helper) { described_class }

  it { is_expected.to respond_to(:bin_path).with(3).arguments }

  describe "#bin_path" do
    let(:cmd) { "sbatch" }
    let(:bin) { Pathname.new("/opt/slurm/bin") }

    context "custom_bin: does not contain an override for cmd" do
      let(:custom_bin) { {} }
      
      it "returns the default path" do
        expect(helper.bin_path(cmd, bin, custom_bin)).to eq(bin.join(cmd).to_s)
      end     
    end

    context "custom_bin: contains an override for cmd" do
      let(:custom_bin) { {cmd => "/usr/local/slurm/bin/sbatch"} }

      it "returns the overridden path" do
        expect(helper.bin_path(cmd, bin, custom_bin)).to eq(custom_bin[cmd])
      end
    end
  end
end