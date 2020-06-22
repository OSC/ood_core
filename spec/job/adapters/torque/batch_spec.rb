require "spec_helper"
require "ood_core/job/adapters/torque"
require "ood_core/job/adapters/torque/batch"

include OodCore::Job::Adapters

describe OodCore::Job::Adapters::Torque::Batch do
  subject(:batch) { described_class.new(host: host, lib: lib, bin: bin) }
  let(:host) { double(to_s: "HOST") }
  let(:bin)  { double(to_s: "BIN")  }
  let(:lib)  { double(to_s: "LIB")  }

  it { is_expected.to respond_to(:host) }
  it { is_expected.to respond_to(:bin) }
  it { is_expected.to respond_to(:lib) }
  it { is_expected.to respond_to(:submit) }

  describe "#host" do
    it { expect(subject.host).to eq("HOST") }
  end

  describe "#bin" do
    it { expect(subject.bin).to eq(Pathname.new("BIN")) }
  end

  describe "#lib" do
    it { expect(subject.lib).to eq(Pathname.new("LIB")) }
  end

  describe "#submit" do
    subject { batch.submit(content, args: args, env: env, chdir: chdir) }
    let(:content) { double(to_s: "CONTENT") }
    let(:args)    { [] }
    let(:env)     { {} }
    let(:chdir)   { nil }

    it "calls the qsub command" do
      expect(Open3).to receive(:capture3).with(
        {
          "PBS_DEFAULT" => "HOST",
          "LD_LIBRARY_PATH" => %{LIB:#{ENV["LD_LIBRARY_PATH"]}}
        },
        "BIN/qsub",
        stdin_data: "CONTENT",
        chdir: '.'
      ) do
        [ "STDOUT", "STDERR", double(success?: true) ]
      end

      is_expected.to eq("STDOUT")
    end

    it "strips away whitespace from qsub output" do
      expect(Open3).to receive(:capture3).with(any_args) do
        [ "\t  \nSTDOUT  \n\t ", "STDERR", double(success?: true) ]
      end

      is_expected.to eq("STDOUT")
    end

    context "when environment variable specified" do
      let(:env) { { double(to_s: "A") => double(to_s: "B") } }

      it "calls the qsub command with that env var" do
        expect(Open3).to receive(:capture3).with(
          {
            "PBS_DEFAULT" => "HOST",
            "LD_LIBRARY_PATH" => %{LIB:#{ENV["LD_LIBRARY_PATH"]}},
            "A" => "B"
          },
          "BIN/qsub",
          stdin_data: "CONTENT",
          chdir: '.'
        ) do
          [ "STDOUT", "STDERR", double(success?: true) ]
        end

        is_expected.to eq("STDOUT")
      end
    end

    context "when command line argument specified" do
      let(:args) { [double(to_s: "a"), double(to_s: "b")] }

      it "calls the qsub command with those arguments" do
        expect(Open3).to receive(:capture3).with(
          {
            "PBS_DEFAULT" => "HOST",
            "LD_LIBRARY_PATH" => %{LIB:#{ENV["LD_LIBRARY_PATH"]}}
          },
          "BIN/qsub",
          "a",
          "b",
          stdin_data: "CONTENT",
          chdir: '.'
        ) do
          [ "STDOUT", "STDERR", double(success?: true) ]
        end

        is_expected.to eq("STDOUT")
      end
    end

    context "when workding directory specified" do
      let(:chdir) { double(to_s: "WORK_DIR") }

      it "calls the qsub command in that working directory" do
        expect(Open3).to receive(:capture3).with(
          {
            "PBS_DEFAULT" => "HOST",
            "LD_LIBRARY_PATH" => %{LIB:#{ENV["LD_LIBRARY_PATH"]}}
          },
          "BIN/qsub",
          stdin_data: "CONTENT",
          chdir: "WORK_DIR"
        ) do
          [ "STDOUT", "STDERR", double(success?: true) ]
        end

        is_expected.to eq("STDOUT")
      end
    end

    context "when qsub returns unsuccessfully" do
      it "raises an error with stderr as message" do
        expect(Open3).to receive(:capture3).with(
          {
            "PBS_DEFAULT" => "HOST",
            "LD_LIBRARY_PATH" => %{LIB:#{ENV["LD_LIBRARY_PATH"]}}
          },
          "BIN/qsub",
          stdin_data: "CONTENT",
          chdir: '.'
        ) do
          [ "STDOUT", "STDERR", double(success?: false) ]
        end

        expect { subject }.to raise_error(Torque::Batch::Error, "STDERR")
      end
    end
  end

  describe "customizing bin paths" do
    let(:script) { OodCore::Job::Script.new(content: "echo 'hi'") }

    context "when calling with no config" do
      it "uses the correct command" do
        batch = OodCore::Job::Adapters::Torque::Batch.new(host: "owens.osc.edu", lib: "/lib", bin: nil, bin_overrides: {})
        allow(Open3).to receive(:capture3).and_return(["job.123", "", double("success?" => true)])

        batch.submit script.content
        expect(Open3).to have_received(:capture3).with(anything, "qsub", any_args)
      end
    end

    context "when calling with normal config" do
      it "uses the correct command" do
        batch = OodCore::Job::Adapters::Torque::Batch.new(host: "owens.osc.edu", lib: "/lib", bin: "/bin", bin_overrides: {})
        allow(Open3).to receive(:capture3).and_return(["job.123", "", double("success?" => true)])

        batch.submit script.content
        expect(Open3).to have_received(:capture3).with(anything, "/bin/qsub", any_args)
      end
    end

    context "when calling with overrides" do
      it "uses the correct command" do
        batch = OodCore::Job::Adapters::Torque::Batch.new(host: "owens.osc.edu", lib: "/lib", bin: nil, bin_overrides: {"qsub" => "not_qsub"})
        allow(Open3).to receive(:capture3).and_return(["job.123", "", double("success?" => true)])

        batch.submit script.content
        expect(Open3).to have_received(:capture3).with(anything, "not_qsub", any_args)
      end
    end
  end

  describe "setting submit_host" do 
    let(:script) { OodCore::Job::Script.new(content: "echo 'hi'") }

    context "when calling without submit_host" do
      it "uses the correct command" do
        batch = OodCore::Job::Adapters::Torque::Batch.new(host: "owens.osc.edu", submit_host: "")
        allow(Open3).to receive(:capture3).and_return(["job.123", "", double("success?" => true)])

        batch.submit script.content
        expect(Open3).to have_received(:capture3).with(anything, "qsub", any_args)
      end
    end

    context "when calling with submit_host" do
      it "uses ssh wrapper" do
        batch = OodCore::Job::Adapters::Torque::Batch.new(host: "pitzer.osc.edu", submit_host: 'owens.osc.edu')
        allow(Open3).to receive(:capture3).and_return(["job.123", "", double("success?" => true)])

        batch.submit script.content
        expect(Open3).to have_received(:capture3).with(anything, "ssh -t -o BatchMode=yes -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no owens.osc.edu \"qsub\"", any_args)
      end
    end
  end
end
