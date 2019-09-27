require "spec_helper"
require "ood_core/job/adapters/fork"
require "ood_core/job/adapters/fork/launcher"


describe OodCore::Job::Adapters::Fork::Launcher do
    def build_script(opts = {})
        OodCore::Job::Script.new({
            accounting_id: nil,
            args: nil,
            content: content,
            email: nil,
            email_on_started: nil,
            email_on_terminated: nil,
            error_path: '/users/PZS0002/mrodgers/stderr_from_fork.log',
            input_path: nil,
            job_array_request: nil,
            job_environment: env = {
                'KEY' => 'value!',
                'CHEESE' => 'Brie'
            },
            job_name: nil,
            output_path: '/users/PZS0002/mrodgers/stdout_from_fork.log',
            native: nil,
            priority: nil,
            queue_name: nil,
            rerunnable: nil,
            reservation_id: nil,
            shell_path: nil,
            start_time: nil,
            submit_as_hold: nil,
            wall_time: 360,
            workdir: '/users/PZS0002/mrodgers/dev/ood_core'
        }.merge opts)
    end

    def content
        <<~HEREDOC
        #!/bin/bash
        # Don't serve your ~/.ssh directory...
        cd /tmp || exit 1
        python -m SimpleHTTPServer
        exit 0
        HEREDOC
    end

    let(:opts) { {
        :adapter => 'fork',
        :ssh_hosts => [
            'owens-login01.hpc.osc.edu',
            'owens-login02.hpc.osc.edu',
            'owens-login03.hpc.osc.edu',
        ],
        :submit_host => 'owens.osc.edu',
        :site_timeout => 20,  # in seconds
        :debug => false,
        :singularity_bin => '/usr/bin/singularity',
        :singularity_image => '/users/PZS0002/mrodgers/centos_latest.sif',
        :strict_host_checking => true,
        :tmux_bin => '/usr/bin/tmux'
    } }

    let(:exit_success) { Struct.new(:success?).new(true) }
    let(:exit_failure) { Struct.new(:success?).new(false) }

    subject(:adapter) {
        described_class.new(**opts)
    }

    describe "#start_remote_session" do
        context "when submission is successful" do
            it "returns a composite of job_id and hostname" do
                allow(Open3).to receive(:capture3).and_return(['remote_host', 'The error message', exit_success])
                expect{
                    subject.start_remote_session(build_script).to match(/.+@remote_host/)
                }
            end
        end

        context "when the job script does not have a shebang" do
            it "raises an error" do
                expect{
                    subject.start_remote_session(build_script({content: ""}))
                }.to raise_error(OodCore::Job::Adapters::Fork::Launcher::Error)
            end
        end

        context "when SSHing to the submission host fails it" do
            it "raises an error" do
                allow(Open3).to receive(:capture3).and_return(['remote_host', '', exit_failure])
                expect{
                    subject.start_remote_session(build_script)
                }.to raise_error(OodCore::Job::Adapters::Fork::Launcher::Error)
            end
        end
    end

    describe "#stop_remote_session" do
        context "when the tmux server is not running" do
            it "does not raise an error" do
                allow(Open3).to receive(:capture3).and_return(['remote_host', 'failed to connect to server', exit_failure])

                subject.stop_remote_session('job', 'remote_host')
            end
        end

        context "when the tmux session name is not found" do
            it "does not raise an error" do
                allow(Open3).to receive(:capture3).and_return(['remote_host', "session not found: #{subject.session_name_label}", exit_failure])

                subject.stop_remote_session('job', 'remote_host')
            end
        end

        context "when SSHing to the execution host fails it" do
            it "raises an error" do
                allow(Open3).to receive(:capture3).and_return(['remote_host', 'SSH failure', exit_failure])

                expect{
                    subject.stop_remote_session('job', 'remote_host')
                }.to raise_error(OodCore::Job::Adapters::Fork::Launcher::Error)
            end
        end
    end

    describe "#list_remote_sessions" do
        let(:tmux_output_a) { "launched-by-ondemand-a8e85cd4-791d-49fa-8be1-5bd5c1009d70\u001F1569609529\u001F175138\n" }
        let(:tmux_output_b) { "launched-by-ondemand-b8e85cd4-791d-49fa-8be1-5bd5c1009d70\u001F1569609529\u001F175138\n" }
        let(:tmux_output_c) { "launched-by-ondemand-c8e85cd4-791d-49fa-8be1-5bd5c1009d70\u001F1569609529\u001F175138\n" }
        let(:parsed_tmux_output_x3) { [
            {
                :destination_host=>"owens-login01.hpc.osc.edu",
                :id=>"launched-by-ondemand-a8e85cd4-791d-49fa-8be1-5bd5c1009d70@owens-login01.hpc.osc.edu",
                :session_created=>"1569609529",
                :session_name=>"launched-by-ondemand-a8e85cd4-791d-49fa-8be1-5bd5c1009d70",
                :session_pid=>"175138"
            },{
                :destination_host=>"owens-login02.hpc.osc.edu",
                :id=>"launched-by-ondemand-b8e85cd4-791d-49fa-8be1-5bd5c1009d70@owens-login02.hpc.osc.edu",
                :session_created=>"1569609529",
                :session_name=>"launched-by-ondemand-b8e85cd4-791d-49fa-8be1-5bd5c1009d70",
                :session_pid=>"175138"
            },{
                :destination_host=>"owens-login03.hpc.osc.edu",
                :id=>"launched-by-ondemand-c8e85cd4-791d-49fa-8be1-5bd5c1009d70@owens-login03.hpc.osc.edu",
                :session_created=>"1569609529",
                :session_name=>"launched-by-ondemand-c8e85cd4-791d-49fa-8be1-5bd5c1009d70",
                :session_pid=>"175138"
            }
        ] }

        context "when host is set" do
            it "only connects to the one host and parses correctly" do
                allow(Open3).to receive(:capture3).and_return([tmux_output_a, '', exit_success])

                expect(Open3).to receive(:capture3).exactly(1).times

                expect(
                    subject.list_remote_sessions(host: 'owens-login01.hpc.osc.edu')
                ).to eq([parsed_tmux_output_x3.first])
            end
        end

        context "when host is not set" do
            it "connects to connects to all SSH hosts and parses correctly" do
                allow(Open3).to receive(:capture3).and_return(
                    [tmux_output_a, '', exit_success],
                    [tmux_output_b, '', exit_success],
                    [tmux_output_c, '', exit_success]
                )

                # Ensure that the test doesn't fail because we forgot we updated opts[:ssh_hosts]
                expect(opts[:ssh_hosts].length).to be(3)
                expect(Open3).to receive(:capture3).exactly(3).times

                expect(
                    subject.list_remote_sessions
                ).to eq(parsed_tmux_output_x3)
            end
        end
    end

    # Private API

    describe "#ssh_cmd" do
        let(:username) { Etc.getlogin }
        context "when strict_host_checking is true" do
            let(:ssh_cmd) { subject.send(:ssh_cmd, 'remote_host') }

            it "uses the correct SSH options" do
                expect(ssh_cmd).to eq(['ssh', '-t', '-o', 'BatchMode=yes', "#{username}@remote_host"])
            end
        end

        context "when strict_host_checking is false" do
            let(:ssh_cmd) { described_class.new(**opts.merge({strict_host_checking: false})).send(:ssh_cmd, 'remote_host') }

            it "uses the correct SSH options" do
                expect(ssh_cmd).to eq([
                    'ssh', '-t',
                    '-o', 'BatchMode=yes',
                    '-o', 'UserKnownHostsFile=/dev/null',
                    '-o', 'StrictHostKeyChecking=no',
                    "#{username}@remote_host"
                ])
            end
        end
    end

    describe "#wrapped_script" do
        context "when job_environment is set" do
            let(:script) {
                subject.send(:wrapped_script, build_script({job_environment: {'ENV_KEY' => 'ENV_VALUE'}}), 'session_name')
            }

            it "is written to the script" do
                expect(script).to match(/export ENV_KEY=ENV_VALUE/)
            end
        end

        context "when env var SINGULARITY_BINDPATH is not set" do
            let(:script) {
                subject.send(:wrapped_script, build_script({job_environment: {}}), 'session_name')
            }
            let(:default_value) { subject.site_singularity_bindpath }

            it "uses the default value" do
                expect(script).to match(/export SINGULARITY_BINDPATH=#{default_value}/)
            end
        end

        context "when env var SINGULARITY_BINDPATH is set" do
            let(:script) {
                subject.send(:wrapped_script, build_script({job_environment: {'SINGULARITY_BINDPATH' => '/home/johstrom'}}), 'session_name')
            }
            let(:default_value) { subject.site_singularity_bindpath }

            it "uses the requested value" do
                expect(script).to match(/export SINGULARITY_BINDPATH=\/home\/johstrom/)
            end
        end

        context "when env var SINGULARITY_CONTAINER is not set by the user script" do
            let(:script) {
                subject.send(:wrapped_script, build_script({job_environment: {}}), 'session_name')
            }
            let(:default_value) { subject.default_singularity_image }

            it "uses the default value" do
                expect(script).to match(/singularity exec --pid #{default_value} \/bin\/bash/)
            end

            it "does not put SINGULARITY_CONTAINER into the environment block" do
                expect(script).not_to match(/export SINGULARITY_CONTAINER=#{default_value}/)
            end
        end

        context "when env var SINGULARITY_CONTAINER is set by the user script" do
            let(:script) {
                subject.send(:wrapped_script, build_script({job_environment: {'SINGULARITY_CONTAINER' => '/home/efranz/image.sif'}}), 'session_name')
            }
            let(:user_value) { subject.default_singularity_image }

            it "uses the default value" do
                expect(script).to match(/singularity exec --pid #{user_value} \/bin\/bash/)
            end

            it "does not put SINGULARITY_CONTAINER into the environment block" do
                expect(script).not_to match(/export SINGULARITY_CONTAINER=#{user_value}/)
            end
        end
    end

    describe "#script_timeout" do
        context "when user requests infinite timeout, but there is a site_timeout" do
            let(:script_timeout) {
                subject.send(:script_timeout, build_script({ wall_time: nil }))
            }
            let(:timeout) { opts[:site_timeout].to_i }

            it "uses the site specified timeout" do
                expect(script_timeout).to be(timeout)
            end
        end

        context "when site_timeout is infinite, but user requests finite timeout" do
            let(:adapter) {
                described_class.new(**opts.merge({site_timeout: 0}))
            }
            let(:script_timeout) {
                adapter.send(:script_timeout, build_script)
            }
            let(:timeout) { build_script.wall_time }

            it "uses user requested wall_time" do
                expect(script_timeout).to be(timeout)
            end
        end

        context "when user timeout is greater than site_timeout, and both are finite" do
            let(:script_timeout) {
                adapter.send(:script_timeout, build_script)
            }
            let(:timeout) { opts[:site_timeout] }

            it "uses user requested wall_time" do
                expect(script_timeout).to be(timeout)
            end
        end

        context "when user timeout is less than site_timeout, and both are finite" do
            let(:user_timeout) { 5 }
            let(:script_timeout) {
                adapter.send(:script_timeout, build_script({wall_time: user_timeout}))
            }

            it "uses user requested wall_time" do
                expect(script_timeout).to be(user_timeout)
            end
        end
    end
end