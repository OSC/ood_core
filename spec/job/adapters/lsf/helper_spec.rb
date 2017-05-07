require "ood_core/job/adapters/lsf"
require "ood_core/job/adapters/lsf/helper"
require "timecop"

describe OodCore::Job::Adapters::Lsf::Helper do
  subject(:helper) { described_class.new() }

  describe "#parse_past_time" do
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

  # FIXME: should move to batch or batch_helper
  describe "#parse_exec_host" do
    it "converts one host" do
      expect(helper.parse_exec_host("compute012")).to eq([{host: "compute012", slots: 1}])
    end

    it "converts multiple hosts with one slot" do
      expect(helper.parse_exec_host("compute033:compute024:compute067")).to eq([
        {host: "compute033", slots: 1},
        {host: "compute024", slots: 1},
        {host: "compute067", slots: 1}
      ])
    end

    it "converts multiple hosts with multiple slots" do
      expect(helper.parse_exec_host("16*compute033:16*compute024:16*compute067")).to eq([
        {host: "compute033", slots: 16},
        {host: "compute024", slots: 16},
        {host: "compute067", slots: 16}
      ])
    end

    it "converts multiple hosts with varying slots" do
      expect(helper.parse_exec_host("compute033:12*compute024:16*compute067")).to eq([
        {host: "compute033", slots: 1},
        {host: "compute024", slots: 12},
        {host: "compute067", slots: 16}
      ])
    end

    it "handles nil" do
      expect(helper.parse_exec_host(nil)).to eq([])
    end
  end

  describe "#estimate_runtime" do
    it "for running job" do
      expect(helper.estimate_runtime(current_time: Time.at(100), start_time: Time.at(10), finish_time: nil)).to eq(90)
    end

    it "for completed job" do
      expect(helper.estimate_runtime(current_time: Time.at(200), start_time: Time.at(10), finish_time: Time.at(100))).to eq(90)
    end

    it "for job not yet started" do
      expect(helper.estimate_runtime(current_time: Time.at(100), start_time: nil, finish_time: nil)).to eq(nil)
    end
  end

  describe "#parse_cpu_used" do
    it "handles normal cases" do
      expect(helper.parse_cpu_used("000:00:00.00")).to eq(0)
      expect(helper.parse_cpu_used("060:24:00.00")).to eq(217440)
      expect(helper.parse_cpu_used("1118:59:09.00")).to eq(4028349)
    end

    it "ignores negative dot seconds" do
      expect(helper.parse_cpu_used("000:00:01.-48")).to eq(1)
      expect(helper.parse_cpu_used("000:01:01.-48")).to eq(61)
    end

    it "handles bad cases" do
      expect(helper.parse_cpu_used("31 seconds")).to eq(nil)
      expect(helper.parse_cpu_used("000:00:00")).to eq(nil)
      expect(helper.parse_cpu_used("25")).to eq(nil)
      expect(helper.parse_cpu_used(nil)).to eq(nil)
    end
  end
end
