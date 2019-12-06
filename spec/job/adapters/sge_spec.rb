require "spec_helper"
require "ood_core/job/adapters/sge"

describe OodCore::Job::Adapters::Sge do
  # # Required arguments
  let(:batch) { double() }
  subject(:adapter) { described_class.new(batch: batch) }

  it { is_expected.to respond_to(:submit).with(1).argument.and_keywords(:after, :afterok, :afternotok, :afterany) }
  it { is_expected.to respond_to(:info_all).with(0).arguments.and_keywords(:attrs) }
  it { is_expected.to respond_to(:info_where_owner).with(1).argument.and_keywords(:attrs) }
  it { is_expected.to respond_to(:info).with(1).argument }
  it { is_expected.to respond_to(:status).with(1).argument }
  it { is_expected.to respond_to(:hold).with(1).argument }
  it { is_expected.to respond_to(:release).with(1).argument }
  it { is_expected.to respond_to(:delete).with(1).argument }
  it { is_expected.to respond_to(:directive_prefix).with(0).arguments }

  it "claims to support job arrays" do
    expect(subject.supports_job_arrays?).to be_truthy
  end


describe "#submit" do
    def build_script(opts = {})
      OodCore::Job::Script.new(
        {
          content: content
        }.merge opts
      )
    end

    let(:batch)  { double(submit: "123") }
    let(:content) { "my batch script" }

    context "when script not defined" do
      it "raises ArgumentError" do
        expect { adapter.submit }.to raise_error(ArgumentError)
      end
    end

    subject { adapter.submit(build_script) }

    it "returns job id" do
      is_expected.to eq("123")
      expect(batch).to have_received(:submit).with(content, ["-cwd"])
    end

    context "with :queue_name" do
      before { adapter.submit(build_script(queue_name: "queue")) }

      it { expect(batch).to have_received(:submit).with(content, ["-cwd", "-q", "queue"]) }
    end

    context "with :submit_as_hold" do
      context "as true" do
        before { adapter.submit(build_script(submit_as_hold: true)) }

        it { expect(batch).to have_received(:submit).with(content, ["-h", "-cwd"]) }
      end

      context "as false" do
        before { adapter.submit(build_script(submit_as_hold: false)) }

        it { expect(batch).to have_received(:submit).with(content, ["-cwd"]) }
      end
    end

    context "with :rerunnable" do
      context "as true" do
        before { adapter.submit(build_script(rerunnable: true)) }

        it { expect(batch).to have_received(:submit).with(content, ["-r", "yes", "-cwd"]) }
      end

      context "as false" do
        before { adapter.submit(build_script(rerunnable: false)) }

        it { expect(batch).to have_received(:submit).with(content, ["-cwd"]) }
      end
    end

    context "with :job_environment" do
      before { adapter.submit(build_script(job_environment: {"key" => "value"})) }

      it { expect(batch).to have_received(:submit).with(content, ["-v", "key=value", "-cwd"]) }
    end

    context "with :workdir" do
      before { adapter.submit(build_script(workdir: "/path/to/workdir")) }

      it { expect(batch).to have_received(:submit).with(content, ["-wd", Pathname.new("/path/to/workdir")]) }
    end

    context "with :email_on_started" do
      context "as true" do
        before { adapter.submit(build_script(email: ["email1", "email2"], email_on_started: true)) }

        it { expect(batch).to have_received(:submit).with(content, ["-cwd", "-M", "email1", "-m", "b"]) }
      end

      context "as false" do
        before { adapter.submit(build_script(email_on_started: false)) }

        it { expect(batch).to have_received(:submit).with(content, ["-cwd"]) }
      end
    end

    context "with :email_on_terminated" do
      context "as true" do
        before { adapter.submit(build_script(email: ["email1", "email2"], email_on_terminated: true)) }

        it { expect(batch).to have_received(:submit).with(content, ["-cwd", "-M", "email1", "-m", "ea"]) }
      end

      context "as false" do
        before { adapter.submit(build_script(email_on_terminated: false)) }

        it { expect(batch).to have_received(:submit).with(content, ["-cwd"]) }
      end
    end

    context "with :email_on_started and :email_on_terminated" do
      before { adapter.submit(build_script(email: ["email1", "email2"], email_on_started: true, email_on_terminated: true)) }

      it { expect(batch).to have_received(:submit).with(content, ["-cwd", "-M", "email1", "-m", "bea"]) }
    end

    context "with :job_name" do
      before { adapter.submit(build_script(job_name: "my_job")) }

      it { expect(batch).to have_received(:submit).with(content, ["-cwd", "-N", "my_job"]) }
    end

    context "with :output_path" do
      before { adapter.submit(build_script(output_path: "/path/to/output")) }

      it { expect(batch).to have_received(:submit).with(content, ["-cwd", "-o", Pathname.new("/path/to/output")]) }
    end

    context "with :error_path" do
      before { adapter.submit(build_script(error_path: "/path/to/error")) }

      it { expect(batch).to have_received(:submit).with(content, ["-cwd", "-e", Pathname.new("/path/to/error")]) }
    end

    context "with :reservation_id" do
      before { adapter.submit(build_script(reservation_id: "my_rsv")) }

      it { expect(batch).to have_received(:submit).with(content, ["-cwd", "-ar", "my_rsv"]) }
    end

    context "with :priority" do
      before { adapter.submit(build_script(priority: 123)) }

      it { expect(batch).to have_received(:submit).with(content, ["-cwd", "-p", 123]) }
    end

    context "with :start_time" do
      before { adapter.submit(build_script(start_time: Time.new(2016, 11, 8, 13, 53, 54).to_i)) }

      it { expect(batch).to have_received(:submit).with(content, ["-cwd", "-a", "201611081353.54"]) }
    end

    context "with :accounting_id" do
      before { adapter.submit(build_script(accounting_id: "my_account")) }

      it { expect(batch).to have_received(:submit).with(content, ["-cwd", "-P", "my_account"]) }
    end

    context "with :wall_time" do
      before { adapter.submit(build_script(wall_time: 94534)) }

      it { expect(batch).to have_received(:submit).with(content, ["-cwd", "-l", "h_rt=26:15:34"]) }
    end

    context "with :native" do
      before { adapter.submit(build_script(native: ["A", "B", "C"])) }

      it { expect(batch).to have_received(:submit).with(content, ["-cwd", "A", "B", "C"]) }
    end

    context "and :afterok is defined as a single job id" do
      before { adapter.submit(build_script, afterok: "job_id") }

      it { expect(batch).to have_received(:submit).with(content, ["-cwd", "-hold_jid_ad", "job_id"]) }
    end

    context "and :afterok is defined as multiple job ids" do
      before { adapter.submit(build_script, afterok: ["job1", "job2"]) }

      it { expect(batch).to have_received(:submit).with(content, ["-cwd", "-hold_jid_ad", "job1,job2"]) }
    end

    context "and when features that SGE does not support are used" do
      it "should raise an error" do
        expect { adapter.submit(build_script, after: [1]) }.to raise_error(OodCore::Job::Adapters::Sge::Error)
        expect { adapter.submit(build_script, afterany: [1]) }.to raise_error(OodCore::Job::Adapters::Sge::Error)
        expect { adapter.submit(build_script, afternotok: [1]) }.to raise_error(OodCore::Job::Adapters::Sge::Error)
      end
    end
  end

  describe "#status" do
  end

  describe "#info" do
  end

  describe "#directive_prefix" do
      context "when called" do
        it "does not raise an error" do
          expect { adapter.directive_prefix }.not_to raise_error
        end
      end
    end
end
