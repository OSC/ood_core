require "spec_helper"
require "ood_core/job/adapters/ccq"

# FakeFile a simple helper class to fake a file
class FakeFile
  attr_reader :path

  def initialize(path)
    @path = path
  end

  def close; end

  def flush; end

  def write(content); end
end

describe OodCore::Job::Adapters::CCQ do
  subject(:adapter) { described_class.new(config: {}) }
  let(:good_ccqsub_output) { 
    "The job has successfully been submitted to the scheduler titan and is" +
    " currently being processed. The job id is: 559529 you can use this id" +
    " to look up the job status using the ccqstat utility." 
  }

  let(:ccqstat_extended) { File.read('spec/fixtures/output/ccq/ccqstat_extended') }
  let(:ccqstat_output) { File.read('spec/fixtures/output/ccq/ccqstat') }
  let(:expected_ccqstat_info) {
    [
      OodCore::Job::Info.new(**{
        id: '432201',
        job_name: 'ccq_ood_script_20200701-29604-1lcxuca',
        job_owner: 'jeff',
        status: 'completed'
      }),
      OodCore::Job::Info.new(**{
        id: '432202',
        job_name: 'ccq_ood_script_20200702-29604-1lcxuca',
        job_owner: 'jeff',
        status: 'running'
      }),
      OodCore::Job::Info.new(**{
        id: '432203',
        job_name: 'ccq_ood_script_20200703-29604-1lcxuca',
        job_owner: 'jeff',
        status: 'queued'
      }),
      OodCore::Job::Info.new(**{
        id: '432204',
        job_name: 'ccq_ood_script_20200704-29604-1lcxuca',
        job_owner: 'jeff',
        status: 'queued'
      }),
      OodCore::Job::Info.new(**{
        id: '432205',
        job_name: 'ccq_ood_script_20200705-29604-1lcxuca',
        job_owner: 'jeff',
        status: 'suspended'
      }),
      OodCore::Job::Info.new(**{
        id: '432206',
        job_name: 'ccq_ood_script_20200706-29604-1lcxuca',
        job_owner: 'jeff',
        status: 'queued'
      }),
      OodCore::Job::Info.new(**{
        id: '432207',
        job_name: 'short_name',
        job_owner: 'jeff',
        status: 'running'
      }),
      OodCore::Job::Info.new(**{
        id: '432208',
        job_name: 'name with spaces',
        job_owner: 'jeff',
        status: 'queued'
      })
    ]
  }

  describe "#info_all" do
    context "when given good data" do
      let(:info_array) { adapter.info_all }

      it "returns good data" do
        `exit 0` # get a good exit status
        allow(Open3).to receive(:capture3).with({}, '/opt/CloudyCluster/srv/CCQ/ccqstat', stdin_data: "").and_return([ccqstat_output, '', $?])

        expect(info_array).to match_array(expected_ccqstat_info)
      end
    end
  end

  describe "#info" do

    context "when ccqstat is good" do
      it "returns good data" do
        `exit 0` # get a good exit status
        allow(Open3).to receive(:capture3).with({}, '/opt/CloudyCluster/srv/CCQ/ccqstat', '-ji', '896090', stdin_data: "").and_return([ccqstat_extended, '', $?])
        info = adapter.info('896090')

        # testing each api directly because it's just to much to test info.native (which is everything)
        expect(info.id).to eql('896090')
        expect(info.status.to_s).to eql('queued')
        expect(info.job_name).to eql('ccq_ood_script_20200409-29862-mxhn1j')
        expect(info.job_owner).to eql('johrstrom')
        expect(info.submit_host).to eql('jeffo-4639-wd-login')
        expect(info.submission_time).to eql(Time.at(1_586_449_678))
        expect(info.dispatch_time).to eql(Time.at(1_586_449_678))
        expect(info.queue_name).to eq('mcn')
      end
    end

    context "when prompted" do
      let(:error_data) {
        "Traceback (most recent call last):\n" +
        "  File \"/opt/CloudyCluster/srv/CCQ/ccqsub\", line 1229, in <module>\n" +
        "    ccqsub(cloudProvider)\n" +
        "  File \"/opt/CloudyCluster/srv/CCQ/ccqsub\", line 567, in ccqsub\n" +
        "    userName = input(\"Please enter your username: \n\")" +
        "EOFError: EOF when reading a line\n"
      }

      it "returns prompt error" do
        `exit 1` # get a bad exit status
        allow(Open3).to receive(:capture3).with({}, '/opt/CloudyCluster/srv/CCQ/ccqstat', '-ji', '896090', stdin_data: "").and_return(['', error_data, $?])

        expect{ adapter.info('896090') }.to raise_error(PromptError)
      end
    end
  end

  describe "#submit" do
    def build_script(opts = {})
      OodCore::Job::Script.new(
        **{
          content: "echo 'hello world'"
        }.merge(opts)
      )
    end

    def configured_adapter(config = {})
      adptr = described_class.new(config)
      allow(adptr).to receive(:make_script_file) { FakeFile.new('/tmp/testfile') }
      allow(adptr).to receive(:parse_job_id_from_ccqsub) { 'jobid.123' }
      adptr
    end

    let(:basic_adapter) { configured_adapter }

    context "when script not defined" do
      it "raises ArgumentError" do
        expect { adapter.submit }.to raise_error(ArgumentError)
      end
    end

    context "when scheduler is defined" do
      let(:cfg_adapter) { configured_adapter(scheduler: 'voyager') }
      let(:expected_args) { ['-s', 'voyager', '-js', '/tmp/testfile'] }

      it "passes the -s arg correctly" do
        expect(cfg_adapter).to receive(:call).with('ccqsub', args: expected_args)
        cfg_adapter.submit(build_script)
      end
    end

    context "when image is defined" do
      let(:cfg_adapter) { configured_adapter(image: 'projects/foo/ubuntu:18') }
      let(:expected_args) { ['-gcpgi', 'projects/foo/ubuntu:18', '-js', '/tmp/testfile'] }

      it "passes the defaults" do
        expect(cfg_adapter).to receive(:call).with('ccqsub', args: expected_args)
        cfg_adapter.submit(build_script)
      end
    end

    context "when gcp cloud and image is defined" do
      let(:cfg_adapter) { configured_adapter(cloud: 'gcp', image: 'projects/foo/ubuntu:18') }
      let(:expected_args) { ['-gcpgi', 'projects/foo/ubuntu:18', '-js', '/tmp/testfile'] }

      it "passes the the gcp image arg" do
        expect(cfg_adapter).to receive(:call).with('ccqsub', args: expected_args )
        cfg_adapter.submit(build_script)
      end
    end

    context "when aws cloud and image is defined" do
      let(:cfg_adapter) { configured_adapter(cloud: 'aws', image: 'ami-1234') }

      it "passes the the aws image arg" do
        expect(cfg_adapter).to receive(:call).with('ccqsub', args: ['-awsami', 'ami-1234', '-js', '/tmp/testfile'])
        cfg_adapter.submit(build_script)
      end
    end

    context "when script specifies output file" do
      let(:expected_args) { ['-o', '/home/me/output.log', '-js', '/tmp/testfile'] }

      it "passes the -o arg" do
        expect(basic_adapter).to receive(:call).with('ccqsub', args: expected_args)
        basic_adapter.submit(build_script(output_path: '/home/me/output.log'))
      end
    end

    context "when script specifies error file" do
      let(:expected_args) {  ['-e', '/home/me/error.log', '-js', '/tmp/testfile'] }

      it "passes the -e arg" do
        expect(basic_adapter).to receive(:call).with('ccqsub', args: expected_args)
        basic_adapter.submit(build_script(error_path: '/home/me/error.log'))
      end
    end

    context "when script specifies walltime" do
      it "passes the -tl arg" do
        args = ['-tl', '03:00:00', '-js', '/tmp/testfile']

        expect(basic_adapter).to receive(:call).with('ccqsub', args: args)
        basic_adapter.submit(build_script(wall_time: 10800))
      end
    end
  end

  describe "#status" do
    context "when ccqstat succeeds" do
      it "returns the correct status" do
        `exit 0` # get a good exit status
        allow(Open3).to receive(:capture3).with({}, '/opt/CloudyCluster/srv/CCQ/ccqstat', '-ji', '896090', stdin_data: "").and_return([ccqstat_extended, '', $?])

        expect(adapter.status('896090').to_s).to eql('queued')
      end
    end
  end

  describe "#directive_prefix" do
    context "when called" do
      it "does not raise an error" do
        expect { adapter.directive_prefix }.not_to raise_error
      end

      it "it is #CC" do
        expect(adapter.directive_prefix).to eq("#CC")
      end
    end
  end

  describe "#parse_job_id_from_ccqsub" do
    context "when given good data" do
      let(:output) { good_ccqsub_output }

      it "parses correclty" do
        expect(adapter.send(:parse_job_id_from_ccqsub, output)).to eq('559529')
      end
    end

    context "when given bad data" do
      let(:output) { "The job script file that was specified (foo) does not exist. Please check the file path and try again." }
      it "throws an error" do
        expect { adapter.send(:parse_job_id_from_ccqsub, output) }.to raise_error(ArgumentError)
      end
    end

    context "when given good data but bad configuration" do
      # named group should be 'job_id' not 'bad_cfg'
      let(:bad_adapter) { described_class.new({:jobid_regex => "job id is: (?<bad_cfg>\\d+) you"}) }
      let(:output) { good_ccqsub_output }

      it "throws an error" do
        expect { bad_adapter.send(:parse_job_id_from_ccqsub, output) }.to raise_error(ArgumentError)
      end
    end
  end

  describe "#hold" do
    context "when called" do
      it "throws an exception" do
        expect { adapter.hold('any id') }.to raise_error(NotImplementedError, "subclass did not define #hold")
      end
    end
  end

  describe "#release" do
    context "when called" do
      it "throws an exception" do
        expect { adapter.release('any id') }.to raise_error(NotImplementedError, "subclass did not define #release")
      end
    end
  end
end
