require "spec_helper"
require "ood_core/job/adapters/helper"

describe OodCore::Job::Adapters::Helper do
  subject(:helper) { described_class }

  it { is_expected.to respond_to(:bin_path).with(3).arguments }

  describe "#bin_path" do
    let(:cmd) { "sbatch" }
    let(:bin) { Pathname.new("/opt/slurm/bin") }

    context "bin_overrides: does not contain an override for cmd" do
      let(:bin_overrides) { {} }
      
      it "returns the default path" do
        expect(helper.bin_path(cmd, bin, bin_overrides)).to eq(bin.join(cmd).to_s)
      end     
    end

    context "bin_overrides: contains an override for cmd" do
      let(:bin_overrides) { {cmd => "/usr/local/slurm/bin/sbatch"} }

      it "returns the overridden path" do
        expect(helper.bin_path(cmd, bin, bin_overrides)).to eq(bin_overrides[cmd])
      end
    end
  end

  describe "#ssh_wrap" do
    let(:cmd) {"sbatch"}

    context "submit_host: empty" do
      let(:submit_host) { "" }

      it "returns the command" do 
        expect(helper.ssh_wrap(cmd, submit_host)).to eq("sbatch")
      end
    end

    context "submit_host: owens.osc.edu" do
      let(:submit_host) { "owens.osc.edu" }

      it "returns the ssh wrapped command" do 
        expect(helper.ssh_wrap(cmd, submit_host)).to eq("ssh -t -o BatchMode=yes -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no owens.osc.edu \"sbatch\"")
      end
    end
  end
end