require "spec_helper"

describe OodCore::Job::Factory do
  describe ".build" do
    context "when config not defined" do
      it "raises ArgumentError" do
        expect { described_class.build }.to raise_error(ArgumentError)
      end
    end

    def build_config(opts = {})
      {}.merge opts
    end

    let(:config)     { build_config }
    let(:config_dbl) { double(to_h: config) }
    subject { described_class.build config_dbl }

    context "when adapter not specified" do
      it "raises OodCore::AdapterNotSpecified" do
        expect { subject }.to raise_error(OodCore::AdapterNotSpecified)
      end
    end

    context "when adapter is specified" do
      let(:config) { build_config(adapter: "my_adapter") }

      context "and build method is created" do
        let(:patched_class) { Class.new(described_class) { def self.build_my_adapter(config); end } }

        it "loads the adapter's code and runs build method" do
          expect(patched_class).to receive(:require).with("ood_core/job/adapters/my_adapter")
          expect(patched_class).to receive(:build_my_adapter).with(config)
          patched_class.build config_dbl
        end
      end

      context "and build method not created" do
        it "loads the adapter's code and raises OodCore::AdapterNotFound" do
          expect(described_class).to receive(:require).with("ood_core/job/adapters/my_adapter")
          expect{ subject }.to raise_error(OodCore::AdapterNotFound)
        end
      end
    end
  end
end
