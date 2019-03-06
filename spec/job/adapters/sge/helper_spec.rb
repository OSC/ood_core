require "spec_helper"
require "ood_core/job/adapters/sge/helper"

describe OodCore::Job::Adapters::Sge::Helper do
  subject(:helper) {described_class.new}

  describe "#script_contains_wd_directive?" do
    let(:match_w_no_space) {'#$-wd /home/ood/ondemand'}
    let(:match_leading_space) {'#$  -wd /home/ood/ondemand'}
    let(:match_cwd) {'#$  -cwd /home/ood/ondemand'}
    let(:match_multiple_directives) {'#$  -wd /home/ood/ondemand'}

    let(:should_not_match_embedded_wd) {' #$ -j yes -o this-wd /home/ood/ondemand'}
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
end