require "spec_helper"
require "ood_core/job/adapters/fork"

describe OodCore::Job::Adapters::Fork do
    let(:launcher) { double() }
    let(:ssh_hosts) { [
        'owens-login01.hpc.osc.edu',
        'owens-login02.hpc.osc.edu',
        'owens-login03.hpc.osc.edu'
    ] }
    subject(:adapter) { 
        described_class.new(ssh_hosts: ssh_hosts, launcher: launcher)
    }

    it "implements the Adapter interface" do
        is_expected.to respond_to(:submit).with(1).argument.and_keywords(:after, :afterok, :afternotok, :afterany)
        is_expected.to respond_to(:info_all).with(0).arguments.and_keywords(:attrs)
        is_expected.to respond_to(:info_where_owner).with(0).arguments.and_keywords(:owner, :attrs)
        is_expected.to respond_to(:info).with(1).argument
        is_expected.to respond_to(:status).with(1).argument
        is_expected.to respond_to(:hold).with(1).argument
        is_expected.to respond_to(:release).with(1).argument
        is_expected.to respond_to(:delete).with(1).argument
        is_expected.to respond_to(:supports_job_arrays?)
    end

    it "does not support job arrays" do
        expect(subject.supports_job_arrays?).to be_falsey
    end
end