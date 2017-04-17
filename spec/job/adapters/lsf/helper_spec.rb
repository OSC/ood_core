require "ood_core/job/adapters/lsf"
require "ood_core/job/adapters/lsf/helper"
require "timecop"

describe OodCore::Job::Adapters::Lsf::Helper do
  subject(:helper) { described_class.new() }

  describe '#parse_past_time' do
    it "converts time using current year" do
      Timecop.freeze(Time.local(2017, 07, 01))

      year = Time.now.year
      expect(helper.parse_past_time("06/31-14:46:42")).to eq(Time.local(year, 6, 31, 14, 46, 42))
      expect(helper.parse_past_time("05/31-12:46:42")).to eq(Time.local(year, 5, 31, 12, 46, 42))

      Timecop.return
    end

    it "handles times from previous year" do
      now = Time.local(2017, 01, 10)
      Timecop.freeze(now)
      expect(Time.now).to eq(now)

      expect(helper.parse_past_time("12/27-12:22:22")).to eq(Time.local(2016, 12, 27, 12, 22, 22))

      Timecop.return
    end

    context "with nil" do
      it { expect(helper.parse_past_time(nil)).to eq(nil) }
    end

    context "with '-'" do
      it { expect(helper.parse_past_time("-")).to eq(nil) }
    end

    context "with ''" do
      it { expect(helper.parse_past_time("")).to eq(nil) }
    end

    context "with unparsable string raise ArgumentError" do
      it "raises ArgumentError" do
        expect { helper.parse_past_time("something not parsable") }.to raise_error(ArgumentError)
      end

      it "returns nil if ignore_errors:true" do
        expect(helper.parse_past_time("something not parsable", ignore_errors: true)).to eq(nil)
      end
    end
  end
end
