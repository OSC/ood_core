describe PBS::Batch do
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
        chdir: nil
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
          chdir: nil
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
          chdir: nil
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
          chdir: nil
        ) do
          [ "STDOUT", "STDERR", double(success?: false) ]
        end

        expect { subject }.to raise_error(PBS::Error, "STDERR")
      end
    end
  end
end
