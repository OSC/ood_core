require "spec_helper"
require "ood_core/job/adapters/linux_host"
require "ood_core/job/adapters/linux_host/launcher"


describe OodCore::Job::Adapters::LinuxHost::Launcher do
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
            job_environment: nil,
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

    let(:exit_success) { double(success?: true) }
    let(:exit_failure) { double(success?: false) }

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

        ## This is a problem for Batch Connect applications which pass a non-shebanged script to the adapter
        # context "when the job script does not have a shebang" do
        #     it "raises an error" do
        #         expect{
        #             subject.start_remote_session(build_script({content: ""}))
        #         }.to raise_error(OodCore::Job::Adapters::LinuxHost::Launcher::Error)
        #     end
        # end

        context "when SSHing to the submission host fails it" do
            it "raises an error" do
                allow(Open3).to receive(:capture3).and_return(['remote_host', '', exit_failure])
                expect{
                    subject.start_remote_session(build_script)
                }.to raise_error(OodCore::Job::Adapters::LinuxHost::Launcher::Error)
            end
        end

        context "when Script#native has submit_host_override set" do
            let(:username) { Etc.getlogin }
            let(:alt_submit_host) { 'pitzer-login01.hpc.osc.edu' }
            it "attempts to connect to the correct host" do
                allow(Open3).to receive(:capture3).and_return([alt_submit_host, '', exit_success])
                # RSpec doesn't seem to have a good way to test a non-first argument in a variadic list
                allow(subject).to receive(:call)
                    .with("ssh", "-t", "-o", "BatchMode=yes", "#{username}@#{alt_submit_host}", any_args)
                    .and_return('')
                
                subject.start_remote_session(build_script(native: {'submit_host_override' => alt_submit_host}))
            end
        end
    end

    describe "#stop_remote_session" do
        context "when the tmux server is not running" do
            it "does not raise an error for 1.8 messages" do
                allow(Open3).to receive(:capture3).and_return(['remote_host', 'failed to connect to server', exit_failure])

                subject.stop_remote_session('job', 'remote_host')
            end

            it "does not raise an error for 2.7 messages" do
                allow(Open3).to receive(:capture3).and_return(['remote_host', 'no server running on /tmp/tmux-30961/default', exit_failure])

                subject.stop_remote_session('job', 'remote_host')
            end
        end

        context "when SSHing to the execution host fails it" do
            it "raises an error" do
                allow(Open3).to receive(:capture3).and_return(['remote_host', 'SSH failure', exit_failure])

                expect{
                    subject.stop_remote_session('job', 'remote_host')
                }.to raise_error(OodCore::Job::Adapters::LinuxHost::Launcher::Error)
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

        context "when SSHing to the execution host fails it" do
            it "raises an error" do
                allow(Open3).to receive(:capture3).and_return(['remote_host', 'SSH failure', exit_failure])

                expect{
                    subject.list_remote_sessions
                }.to raise_error(OodCore::Job::Adapters::LinuxHost::Launcher::Error)
            end
        end
    end

    # Private API

    describe "#ssh_cmd" do
        let(:username) { Etc.getlogin }
        context "when strict_host_checking is true" do
            let(:ssh_cmd) { subject.send(:ssh_cmd, 'remote_host', ['/bin/bash']) }

            it "uses the correct SSH options" do
                expect(ssh_cmd).to eq(['ssh', '-t', '-o', 'BatchMode=yes', "#{username}@remote_host", '/bin/bash'])
            end
        end

        context "when strict_host_checking is false" do
            let(:ssh_cmd) { 
                described_class.new(**opts.merge({strict_host_checking: false})).send(:ssh_cmd, 'remote_host', ['/bin/bash']) 
            }

            it "uses the correct SSH options" do
                expect(ssh_cmd).to eq([
                    'ssh', '-t',
                    '-o', 'BatchMode=yes',
                    '-o', 'UserKnownHostsFile=/dev/null',
                    '-o', 'StrictHostKeyChecking=no',
                    "#{username}@remote_host",
                    "/bin/bash"
                ])
            end
        end
    end

    describe "#wrapped_script" do
        context "when :accounting_id" do
            # Does not support an accounting_id
        end

        context "when :args" do
            let(:script) {
                subject.send(:wrapped_script, build_script({args: ['ARG_A', 'ARG_B', 'ARG_C']}), 'session_name')
            }

            it "is written to the script" do
                expect(script).to match(/ARG_A ARG_B ARG_C/)
            end
        end

        context "when :args contain shell special characters" do
            let(:script) {
                subject.send(:wrapped_script, build_script({args: ['#!this n that', '; cat ~/.ssh/id_rsa > ~attacker/their_private_key', 'ARG_C']}), 'session_name')
            }

            it "is written to the script escaped" do
                expect(script).to include('\#\!this\ n\ that \;\ cat\ \~/.ssh/id_rsa\ \>\ \~attacker/their_private_key ARG_C')
            end
        end

        context "when :email and :email_on_started" do
            let(:script) {
                subject.send(:wrapped_script, build_script({
                    email: ['efranz@osc.edu', 'johrstrom@osc.edu', 'mrodgers@osc.edu'],
                    email_on_started: true
                }), 'session_name')
            }

            it "is set in the script" do
                expect(script).to include('has started" efranz@osc.edu, johrstrom@osc.edu, mrodgers@osc.edu')
            end
        end

        context "when :email and :email_on_terminated" do
            let(:script) {
                subject.send(:wrapped_script, build_script({
                    email: ['efranz@osc.edu', 'johrstrom@osc.edu', 'mrodgers@osc.edu'],
                    email_on_terminated: true
                }), 'session_name')
            }

            it "is set in the script" do
                expect(script).to include('has terminated" efranz@osc.edu, johrstrom@osc.edu, mrodgers@osc.edu')
            end
        end

        context "when :error_path" do
            let(:script_with_explicit_error_path) {
                subject.send(:wrapped_script, build_script({
                    error_path: "/home/efranz/stderr.log"
                }), 'session_name')
            }

            let(:script_with_nil_error_path) {
                subject.send(:wrapped_script, build_script({
                    error_path: nil
                }), 'session_name')
            }

            let(:script_with_both_paths_nil) {
                subject.send(:wrapped_script, build_script({
                    error_path: nil,
                    output_path: nil,
                }), 'session_name')
            }

            it "is set in the script" do
                expect(script_with_explicit_error_path).to include('ERROR_PATH=/home/efranz/stderr.log')
            end

            it "is not set in the script when there's no output_path" do
                expect(script_with_both_paths_nil).to include('ERROR_PATH=/dev/null')
            end

            it "uses output_path if it exists" do
                expect(script_with_nil_error_path).to include('ERROR_PATH=/users/PZS0002/mrodgers/stdout_from_fork.log')
            end
        end

        context "when :input_path" do
            # Does not support an input_path
        end

        context "when :job_array_request" do
            # Does not support job arrays
        end

        context "when :job_environment" do
            let(:script) {
                subject.send(:wrapped_script, build_script({job_environment: {'ENV_KEY' => 'ENV_VALUE'}}), 'session_name')
            }

            it "is written to the script" do
                expect(script).to match(/export ENV_KEY=ENV_VALUE/)
            end
        end

        context "when :job_name (and :email and one of :email_on_*)" do
            let(:script) {
                subject.send(:wrapped_script, build_script({
                    job_name: 'Useful job name',
                    email: ['efranz@osc.edu'],
                    email_on_started: true
                }), 'session_name')
            }

            it "is set in the script" do
                expect(script).to include('mail -s "Job Useful job name has')
                expect(script).to include('Your job Useful job name has')
            end
        end

        context "when :output_path" do
            let(:script_with_explicit_output_path) {
                subject.send(:wrapped_script, build_script({
                    output_path: "/home/efranz/stdout.log"
                }), 'session_name')
            }

            let(:script_with_nil_output_path) {
                subject.send(:wrapped_script, build_script({
                    output_path: nil
                }), 'session_name')
            }

            it "is set in the script" do
                expect(script_with_explicit_output_path).to include('OUTPUT_PATH=/home/efranz/stdout.log')
            end

            it "is not set in the script" do
                expect(script_with_nil_output_path).to include('OUTPUT_PATH=/dev/null')
            end
        end

        context "when :native singularity_bindpath is not set" do
            let(:script) {
                subject.send(:wrapped_script, build_script({native: {:singularity_bindpath => nil}}), 'session_name')
            }
            let(:default_value) { subject.site_singularity_bindpath }

            it "uses the default value" do
                expect(script).to match(/export SINGULARITY_BINDPATH=#{default_value}/)
            end
        end

        context "when :native singularity_bindpath is set" do
            let(:script) {
                subject.send(:wrapped_script, build_script({native: {:singularity_bindpath => '/home/johrstrom'}}), 'session_name')
            }
            let(:default_value) { subject.site_singularity_bindpath }

            it "uses the configured value" do
                expect(script).to match(/export SINGULARITY_BINDPATH=\/home\/johrstrom/)
            end
        end

        context "when :native singularity_container is not set" do
            let(:script) {
                subject.send(:wrapped_script, build_script({native: {:singularity_container => nil}}), 'session_name')
            }
            let(:default_value) { subject.default_singularity_image }

            it "uses the default value" do
                expect(script).to match(/singularity exec\s+--pid #{default_value} \/bin\/bash/)
            end
        end

        context "when :native singularity_container is set" do
            let(:base_image) { '/apps/base_image.sif' }
            let(:script) {
                subject.send(:wrapped_script, build_script({native: {:singularity_container => base_image}}), 'session_name')
            }

            it "uses the default value" do
                expect(script).to match(/singularity exec\s+--pid #{base_image} \/bin\/bash/)
            end
        end

        context "when :priority" do
            # Does not support priority
        end

        context "when :queue_name" do
            # Does not support queues
        end

        context "when :rerunnable" do
            # Does not support rerunning jobs
        end

        context "when :reservation_id" do
            # Does not support reservations
        end

        context "when :shell_path" do
            # Does not support a shell path; script.content is expected to begin with a shebang
        end

        context "when :start_time" do
            # Does not support deferred start; could be implmented using `at`
        end

        context "when :submit_as_hold" do
            # Does not support holding the job
        end

        context "when :wall_time" do
            # for tests on user/site timeout conflict see #script_timeout
            let(:script) {
                subject.send(:wrapped_script, build_script({
                    wall_time: 60
                }), 'session_name')
            }

            it "is set in the script" do
                expect(script).to match(/TMUX_LAUNCHER.+timeout \d+s.+TMUX_LAUNCHER/m)
            end
        end

        context "when :workdir" do
            let(:script) {
                subject.send(:wrapped_script, build_script({
                    workdir: '/fs/project/PZS0174/mrodgers'
                }), 'session_name')
            }

            it "is set in the script" do
                expect(script).to match(/TMUX_LAUNCHER.+cd \/fs\/project\/PZS0174\/mrodgers.+TMUX_LAUNCHER/m)
            end
        end

        context "when contain is truthy" do
            let(:script) {
                described_class.new(
                    **opts.merge({:contain => true})
                ).send(
                    :wrapped_script, build_script({job_environment: {}}), 'session_name'
                )
            }

            it "generates the --contain flag" do
                expect(script).to match(/singularity exec\s+--contain\s+--pid/)
            end
        end

        context "when env var SINGULARITY_CONTAINER is set by the user script" do
            let(:script) {
                subject.send(:wrapped_script, build_script({job_environment: {'SINGULARITY_CONTAINER' => '/home/efranz/image.sif'}}), 'session_name')
            }
            let(:user_value) { subject.default_singularity_image }

            it "uses the default value" do
                expect(script).to match(/singularity exec\s+--pid #{user_value} \/bin\/bash/)
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