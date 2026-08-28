# spec/job/adapters/systemd/launcher_spec.rb
require "spec_helper"
require "ood_core/job/adapters/systemd"
require "ood_core/job/adapters/systemd/launcher"

describe OodCore::Job::Adapters::LinuxSystemd::Launcher do
  let(:opts) do 
    {
    :ssh_hosts => [
      'owens-login01.hpc.osc.edu',
      'owens-login02.hpc.osc.edu',
    ],
    :submit_host          => 'owens.osc.edu',
    :site_timeout         => 20,
    :debug                => false,
    :strict_host_checking => true,
    } 
  end

  # Launcher to be called in contexts
  subject(:launcher) { described_class.new(**opts) }

  # default script for tests unless overridden by context
  def build_script(script_opts = {})
    OodCore::Job::Script.new(**{
      content: "#!/bin/bash\necho test" 
    }.merge(script_opts))
  end

  describe "#ssh_cmd" do
    let(:username) { Etc.getlogin }

    context "when strict_host_checking is true" do
      it "omits the host key checking options" do
        expect(launcher.send(:ssh_cmd, 'remote_host', ['/bin/bash'])).to eq([
          'ssh', '-t',
          '-p', '22',
          '-o', 'Batchmode=yes',
          "#{username}@remote_host",
          '/bin/bash'
        ])
      end
    end
  end

  describe "#script_timeout" do
    context "when site_timeout is 0" do
      let(:launcher) { described_class.new(**opts.merge(site_timeout: 0)) }

      it "returns 'infinity' when wall_time is also 0" do
        script = build_script(wall_time: 0)
        expect(launcher.send(:script_timeout, script)).to eq('infinity')
      end

      it "returns wall_time when wall_time is set" do
        script = build_script(wall_time: 1)
        expect(launcher.send(:script_timeout, script)).to eq(1)
      end
    end

    context "when site_timeout is not 0" do
      let(:launcher) { described_class.new(**opts.merge(site_timeout: 200)) }

      it "returns site_timeout when site_timeout < wall_time" do
        script = build_script(wall_time: 300)
        expect(launcher.send(:script_timeout, script)).to eq(200)
      end

      it "returns wall_time when wall_time < site_timeout" do
        script = build_script(wall_time: 100)
        expect(launcher.send(:script_timeout, script)).to eq(100)
      end

      it "returns site_timeout when wall_time is 0" do
        script = build_script(wall_time: 0)
        expect(launcher.send(:script_timeout, script)).to eq(200)
      end

      it "treats nil wall_time the same as a 0 wall_time" do
        script = build_script
        expect(launcher.send(:script_timeout, script)).to eq(200)
      end
    end
  end

  describe "#parse_hostname" do
    it "returns the hostname from HOSTNAME line" do
      output = "blah noise\nHOSTNAME:owens-login01.hpc.osc.edu\nmore noise blah"
      expect(launcher.send(:parse_hostname, output)).to eq('owens-login01.hpc.osc.edu')
    end

    it "returns last set hostname when multiple hostnames are set" do
      output = "blah\nHOSTNAME:owens-login01.hpc.osc.edu\nblah\nHOSTNAME:owens-login02.hpc.osc.edu\nblah"
      expect(launcher.send(:parse_hostname, output)).to eq('owens-login02.hpc.osc.edu')
    end

    it "returns empty string when no hostname is set" do
      output = "blah\nHOSTNAME:\nblah"
      expect(launcher.send(:parse_hostname, output)).to eq('')
    end

    it "returns empty string when hostname is entirely absent" do
      output = "blah\nblah\nblah"
      expect(launcher.send(:parse_hostname, output)).to eq('')
    end
  end

  describe "#user_script_has_shebang?" do
    it "returns true when the first line is a shebang" do
      script = build_script(content: "#!/bin/bash\necho test")
      expect(launcher.send(:user_script_has_shebang?, script)).to be(true)
    end
  
    it "returns false when the content is empty" do
      script = build_script(content: '')
      expect(launcher.send(:user_script_has_shebang?, script)).to be(false)
    end
  
    it "returns false when the first line is not a shebang" do
      script = build_script(content: "echo test\n#!/bin/bash")
      expect(launcher.send(:user_script_has_shebang?, script)).to be(false)
    end
  end

  describe "#script_arguments" do
    it "returns an empty string when args is nil" do
      script = build_script
      expect(launcher.send(:script_arguments, script)).to eq('')
    end
  
    it "returns an empty string when args is an empty array" do
      script = build_script(args: [])
      expect(launcher.send(:script_arguments, script)).to eq('')
    end
  
    it "joins multiple arguments with spaces" do
      script = build_script(args: ['--verbose', '--output', 'file.txt'])
      expect(launcher.send(:script_arguments, script)).to eq('--verbose --output file.txt')
    end
  
    it "shell-escapes arguments containing spaces" do
      script = build_script(args: ['my file.txt'])
      expect(launcher.send(:script_arguments, script)).to eq('my\ file.txt')
    end
  end

  describe "#export_env" do
    it "returns an empty string when job_environment is nil" do
      script = build_script
      expect(launcher.send(:export_env, script)).to eq('')
    end
  
    it "builds an export line for each variable" do
      script = build_script(job_environment: { 'FOO' => 'bar' })
      expect(launcher.send(:export_env, script)).to eq('export FOO=bar')
    end
  
    it "sorts the export lines" do
      script = build_script(job_environment: { 'ZED' => '1', 'ALPHA' => '2' })
      expect(launcher.send(:export_env, script)).to eq("export ALPHA=2\nexport ZED=1")
    end
  
    it "shell-escapes values containing spaces" do
      script = build_script(job_environment: { 'MSG' => 'hello world' })
      expect(launcher.send(:export_env, script)).to eq('export MSG=hello\ world')
    end
  end

  describe "#error_path" do
    it "returns the error_path when it is set" do
      script = build_script(error_path: '/tmp/err.log')
      expect(launcher.send(:error_path, script)).to eq('/tmp/err.log')
    end
  
    it "falls back to output_path when error_path is nil" do
      script = build_script(output_path: '/tmp/out.log')
      expect(launcher.send(:error_path, script)).to eq('/tmp/out.log')
    end
  
    it "prefers error_path when both are set" do
      script = build_script(error_path: '/tmp/err.log', output_path: '/tmp/out.log')
      expect(launcher.send(:error_path, script)).to eq('/tmp/err.log')
    end
  
    it "returns /dev/null when neither is set" do
      script = build_script
      expect(launcher.send(:error_path, script)).to eq('/dev/null')
    end
  
    it "returns a String, not a Pathname" do
      script = build_script(error_path: '/tmp/err.log')
      expect(launcher.send(:error_path, script)).to be_a(String)
    end
  end

  describe "#unique_session_name" do
    it "is prefixed with the session name label" do
      expect(launcher.send(:unique_session_name)).to start_with('ondemand-')
    end
  
    it "appends 10 alphanumeric characters" do
      expect(launcher.send(:unique_session_name)).to match(/\Aondemand-[a-zA-Z0-9]{10}\z/)
    end
  
    it "returns a different name on each call" do
      expect(launcher.send(:unique_session_name)).not_to eq(launcher.send(:unique_session_name))
    end
  end

  describe "#submit_host" do
    it "returns the configured submit_host when no script is given" do
      expect(launcher.submit_host).to eq('owens.osc.edu')
    end
  
    it "returns the configured submit_host when the script has no native options" do
      script = build_script
      expect(launcher.submit_host(script)).to eq('owens.osc.edu')
    end
  
    it "returns the configured submit_host when native has no override key" do
      script = build_script(native: { 'something_else' => 'value' })
      expect(launcher.submit_host(script)).to eq('owens.osc.edu')
    end
  
    it "returns the override when native specifies submit_host_override" do
      script = build_script(native: { 'submit_host_override' => 'other.osc.edu' })
      expect(launcher.submit_host(script)).to eq('other.osc.edu')
    end
  end
end