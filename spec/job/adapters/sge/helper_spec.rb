require "spec_helper"
require "ood_core/job/adapters/sge/helper"

describe OodCore::Job::Adapters::Sge::Helper do
  subject(:helper) {described_class.new}

  describe "#script_contains_wd_directive?" do
    let(:match_w_no_space) {'#$-wd /home/ood/ondemand'}
    let(:match_leading_space) {'#$  -wd /home/ood/ondemand'}
    let(:match_cwd) {'#$  -cwd /home/ood/ondemand'}
    let(:match_multiple_directives) {'#$  -wd /home/ood/ondemand'}

    let(:should_not_match_embedded_wd) {'#$ -j yes -o this-wd /home/ood/ondemand'}
    let(:should_not_match_bad_indent) {'  #$ -t 1-10:5 -wd /home/ood/ondemand'}

    it "detects c?wd directives in a script" do
        expect(helper.script_contains_wd_directive?(match_w_no_space)).to be_truthy
        expect(helper.script_contains_wd_directive?(match_leading_space)).to be_truthy
        expect(helper.script_contains_wd_directive?(match_cwd)).to be_truthy
        expect(helper.script_contains_wd_directive?(match_multiple_directives)).to be_truthy

        expect(helper.script_contains_wd_directive?(should_not_match_embedded_wd)).to be_falsey
        expect(helper.script_contains_wd_directive?(should_not_match_bad_indent)).to be_falsey
    end
  end

  describe "#job_name" do
    let(:sftp_command_as_job_name) { 'sftp://user@host.edu/place:22' }
    let(:acceptable_job_name) { 'bioinformatics_job_01' }
    let(:batch_connect_job_name) { 'ondemand/sys/dashboard/sys/bc_osc_rstudio_server' }
    # http://gridscheduler.sourceforge.net/htmlman/htmlman1/sge_types.html?pathrev=V62u5_TAG
    let(:legal_ge_name_regex) { /^((?![\n\t\r\/:@\\*])[[:ascii:]])*$/ }

    context "when santize_job_name is unset" do
        it "returns the correct job_name" do
            expect(acceptable_job_name).to match(legal_ge_name_regex)
            expect(helper.job_name(acceptable_job_name)).to eq(acceptable_job_name)
            expect(helper.job_name(sftp_command_as_job_name)).to eq(sftp_command_as_job_name)
            expect(helper.job_name(batch_connect_job_name)).to eq(batch_connect_job_name)
        end
    end

    context "when santize_job_name is true" do
        it "returns the correct job_name" do
            expect(acceptable_job_name).to match(legal_ge_name_regex)
            expect(helper.job_name(acceptable_job_name, true)).to match(legal_ge_name_regex)
            expect(helper.job_name(sftp_command_as_job_name, true)).to match(legal_ge_name_regex)
            expect(helper.job_name(batch_connect_job_name, true)).to match(legal_ge_name_regex)
        end
    end
  end
end