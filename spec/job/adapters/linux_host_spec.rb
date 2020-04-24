require "spec_helper"
require "ood_core/job/adapters/linux_host"

describe OodCore::Job::Adapters::LinuxHost do
    let(:launcher) { double() }
    let(:ssh_hosts) { [
        'owens-login01.hpc.osc.edu',
        'owens-login02.hpc.osc.edu',
        'owens-login03.hpc.osc.edu'
    ] }
    subject(:adapter) {
        described_class.new(ssh_hosts: ssh_hosts, launcher: launcher)
    }
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
    let(:session_created) { Time.now.to_i - 60 }
    let(:ellapsed) { Time.now.to_i - session_created }
    let(:returned_job_infos_x3) { [
        OodCore::Job::Info.new(**{
          :accounting_id => nil,
          :allocated_nodes => [
            OodCore::Job::NodeInfo.new(
              name: 'owens-login01.hpc.osc.edu',
              procs: 1
            )
          ],
          :cpu_time => 243247,
          :dispatch_time => '2019-09-27 14:38:49 -0400',
          :id => 'launched-by-ondemand-a8e85cd4-791d-49fa-8be1-5bd5c1009d70@owens-login01.hpc.osc.edu',
          :job_name => nil,
          :job_owner => 'mrodgers',
          :native => {
            :destination_host => 'owens-login01.hpc.osc.edu',
            :id => 'launched-by-ondemand-a8e85cd4-791d-49fa-8be1-5bd5c1009d70@owens-login01.hpc.osc.edu',
            :session_created => session_created,
            :session_name => 'launched-by-ondemand-a8e85cd4-791d-49fa-8be1-5bd5c1009d70',
            :session_pid => '175138'
          },
          :procs => 1,
          :queue_name => 'Fork adapter for ',
          :status => 'running',
          :submission_time => '2019-09-27 14:38:49 -0400',
          :submit_host => nil,
          :tasks => [],
          :wallclock_limit => nil,
          :wallclock_time => ellapsed
        }),
        OodCore::Job::Info.new(**{
          :accounting_id => nil,
          :allocated_nodes => [
            OodCore::Job::NodeInfo.new(
              name: 'owens-login02.hpc.osc.edu',
              procs: 1
            )
          ],
          :cpu_time => 243247,
          :dispatch_time => '2019-09-27 14:38:49 -0400',
          :id => 'launched-by-ondemand-b8e85cd4-791d-49fa-8be1-5bd5c1009d70@owens-login02.hpc.osc.edu',
          :job_name => nil,
          :job_owner => 'mrodgers',
          :native => {
            :destination_host => 'owens-login01.hpc.osc.edu',
            :id => 'launched-by-ondemand-b8e85cd4-791d-49fa-8be1-5bd5c1009d70@owens-login02.hpc.osc.edu',
            :session_created => session_created,
            :session_name => 'launched-by-ondemand-b8e85cd4-791d-49fa-8be1-5bd5c1009d70',
            :session_pid => '175138'
          },
          :procs => 1,
          :queue_name => 'Fork adapter for ',
          :status => 'running',
          :submission_time => '2019-09-27 14:38:49 -0400',
          :submit_host => nil,
          :tasks => [],
          :wallclock_limit => nil,
          :wallclock_time => ellapsed
        }),
        OodCore::Job::Info.new(**{
          :accounting_id => nil,
          :allocated_nodes => [
            OodCore::Job::NodeInfo.new(
              name: 'owens-login03.hpc.osc.edu',
              procs: 1
            )
          ],
          :cpu_time => 243247,
          :dispatch_time => '2019-09-27 14:38:49 -0400',
          :id => 'launched-by-ondemand-c8e85cd4-791d-49fa-8be1-5bd5c1009d70@owens-login03.hpc.osc.edu',
          :job_name => nil,
          :job_owner => 'mrodgers',
          :native => {
            :destination_host => 'owens-login01.hpc.osc.edu',
            :id => 'launched-by-ondemand-c8e85cd4-791d-49fa-8be1-5bd5c1009d70@owens-login03.hpc.osc.edu',
            :session_created => session_created,
            :session_name => 'launched-by-ondemand-c8e85cd4-791d-49fa-8be1-5bd5c1009d70',
            :session_pid => '175138'
          },
          :procs => 1,
          :queue_name => 'Fork adapter for ',
          :status => 'running',
          :submission_time => '2019-09-27 14:38:49 -0400',
          :submit_host => nil,
          :tasks => [],
          :wallclock_limit => nil,
          :wallclock_time => ellapsed
        })
    ] }

    it "implements the Adapter interface" do
        is_expected.to respond_to(:submit).with(1).argument.and_keywords(:after, :afterok, :afternotok, :afterany)
        is_expected.to respond_to(:info_all).with(0).arguments.and_keywords(:attrs)
        is_expected.to respond_to(:info_where_owner).with(1).arguments.and_keywords(:attrs)
        is_expected.to respond_to(:info).with(1).argument
        is_expected.to respond_to(:status).with(1).argument
        is_expected.to respond_to(:hold).with(1).argument
        is_expected.to respond_to(:release).with(1).argument
        is_expected.to respond_to(:delete).with(1).argument
        is_expected.to respond_to(:supports_job_arrays?)
        is_expected.to respond_to(:directive_prefix).with(0).arguments
    end

    it "does not support job arrays" do
        expect(subject.supports_job_arrays?).to be_falsey
    end

    describe "#submit" do
        def build_script(opts = {})
          OodCore::Job::Script.new(
            {
              content: content
            }.merge opts
          )
        end

        let(:content) {"#!/bin/bash\necho 'hi'"}

        context "when script not defined" do
          it "raises ArgumentError" do
            expect { adapter.submit }.to raise_error(ArgumentError)
          end
        end

        context "when OodCore::Job::Adapters::LinuxHost::Launcher::Error is raised" do
          before { expect(launcher).to receive(:start_remote_session).and_raise(OodCore::Job::Adapters::LinuxHost::Launcher::Error) }

          it "raises OodCore::JobAdapterError" do
            expect { adapter.submit(build_script) }.to raise_error(OodCore::JobAdapterError)
          end
        end

        context "when the developer attempts to use an unsupported argument" do
            it "raises OodCore::JobAdapterError" do
                expect { adapter.submit(build_script, after: [1, 2])}.to raise_error(OodCore::JobAdapterError)
                expect { adapter.submit(build_script, afterok: [1, 2])}.to raise_error(OodCore::JobAdapterError)
                expect { adapter.submit(build_script, afternotok: [1, 2])}.to raise_error(OodCore::JobAdapterError)
                expect { adapter.submit(build_script, afterany: [1, 2])}.to raise_error(OodCore::JobAdapterError)
            end
        end
    end

    # Note that info_all is the base implementation for all #info* methods
    # as well as #status
    describe "#info_all" do
        context "when no jobs are found" do
            before { expect(launcher).to receive(:list_remote_sessions).and_return([]) }

            it "returns an array of all the jobs" do
                expect( subject.info_all ).to eq([])
            end
        end

        context "when one job is found" do
            before { expect(launcher).to receive(:list_remote_sessions).and_return(parsed_tmux_output_x3.slice(0..0)) }

            it "returns an array of all the jobs" do
                returned_jobs = subject.info_all
                expect(returned_jobs.length).to eq(1)
                job = returned_jobs.first
                comparison_job = returned_job_infos_x3.first

                expect(job.id).to eq(comparison_job.id)
                expect(job.allocated_nodes).to eq(comparison_job.allocated_nodes)
                expect(job.status).to eq(comparison_job.status)
            end
        end

        context "when multiple jobs are found" do
            before { expect(launcher).to receive(:list_remote_sessions).and_return(parsed_tmux_output_x3) }

            it "returns an array of all the jobs" do
                returned_jobs = subject.info_all
                expect(returned_jobs.length).to eq(3)

                returned_jobs.zip(returned_job_infos_x3).each do |job_a, job_b|
                    expect(job_a.id).to eq(job_b.id)
                    expect(job_a.allocated_nodes).to eq(job_b.allocated_nodes)
                    expect(job_a.status).to eq(job_b.status)
                end
            end
        end

        context "when OodCore::Job::Adapters::LinuxHost::Launcher::Error is raised" do
          before { expect(launcher).to receive(:list_remote_sessions).and_raise(OodCore::Job::Adapters::LinuxHost::Launcher::Error) }

          it "raises OodCore::JobAdapterError" do
            expect { adapter.info_all }.to raise_error(OodCore::JobAdapterError)
          end
        end
    end

    describe "#info" do
        context "when id is not defined" do
          it "raises ArgumentError" do
            expect { adapter.info }.to raise_error(ArgumentError)
          end
        end

        context "when the job is not found" do
            before { expect(launcher).to receive(:list_remote_sessions).and_return(parsed_tmux_output_x3) }

            it "returns a completed job" do
                expect(adapter.info('not_running@owens-login01.hpc.osc.edu').status).to eq(OodCore::Job::Status.new(state: :completed))
            end
        end

        context "when the job is found" do
            before { expect(launcher).to receive(:list_remote_sessions).and_return(parsed_tmux_output_x3) }

            it "returns the correct Info" do
                comparison_job = returned_job_infos_x3.first
                info = adapter.info(comparison_job.id)

                expect(info.id).to eq(comparison_job.id)
                expect(info.allocated_nodes).to eq(comparison_job.allocated_nodes)
                expect(info.status).to eq(comparison_job.status)
            end
        end
    end

    describe "#status" do
        context "when id is not defined" do
          it "raises ArgumentError" do
            expect { adapter.status }.to raise_error(ArgumentError)
          end
        end

        context "when a job is running" do
            before { expect(launcher).to receive(:list_remote_sessions).and_return(parsed_tmux_output_x3.slice(0..0)) }

            it "returns the correct status" do
                expect(adapter.status(parsed_tmux_output_x3.first[:id])).to eq(returned_job_infos_x3.first.status)
            end
        end

        context "when a job is not running" do
            before { expect(launcher).to receive(:list_remote_sessions).and_return(parsed_tmux_output_x3.slice(0..0)) }

            it "returns the correct status" do
                expect(adapter.status('not_a_job@owens-login03.hpc.osc.edu')).to eq(:completed)
            end
        end
    end

    describe "#hold" do
        context "when #hold is called" do
            it "raises NotImplementedError" do
                expect{adapter.hold('an_id@owens-login01.hpc.osc.edu')}.to raise_error(NotImplementedError)
            end
        end
    end

    describe "#release" do
        context "when #release is called" do
            it "raises NotImplementedError" do
                expect{adapter.release('an_id@owens-login01.hpc.osc.edu')}.to raise_error(NotImplementedError)
            end
        end
    end

    describe "#delete" do
        context "when called with an id" do
            it "calls stop_remote_session" do
                expect(launcher).to receive(:stop_remote_session)

                subject.delete('jobid@owens-login01.hpc.osc.edu')
            end
        end

        context "when OodCore::Job::Adapters::LinuxHost::Launcher::Error is raised" do
          before { expect(launcher).to receive(:stop_remote_session).and_raise(OodCore::Job::Adapters::LinuxHost::Launcher::Error) }

          it "raises OodCore::JobAdapterError" do
            expect { adapter.delete('jobid@owens-login01.hpc.osc.edu') }.to raise_error(OodCore::JobAdapterError)
          end
        end
    end

    describe "#directive_prefix" do
      context "when called" do
        it "returns nil" do
          expect(adapter.directive_prefix).to eq(nil)
        end
      end
    end
end
