RSpec.describe PBS do

  subject { PBS }

  # methods
  it { is_expected.to respond_to(:pbs_connect) }
  it { is_expected.to respond_to(:pbs_default) }
  it { is_expected.to respond_to(:pbs_deljob) }
  it { is_expected.to respond_to(:pbs_disconnect) }
  it { is_expected.to respond_to(:pbs_statfree) }
  it { is_expected.to respond_to(:pbs_statjob) }
  it { is_expected.to respond_to(:pbs_statnode) }
  it { is_expected.to respond_to(:pbs_statque) }
  it { is_expected.to respond_to(:pbs_statserver) }
  it { is_expected.to respond_to(:pbs_submit) }
  it { is_expected.to respond_to(:error) }
  it { is_expected.to respond_to(:error?) }
  it { is_expected.to respond_to(:reset_error) }

  let(:server) { PBS::pbs_default() }
  let(:conn) { PBS::pbs_connect(server) }

  after(:each, :disconnect => true) do
    PBS::pbs_disconnect(conn)
  end

  describe "::pbs_default" do
    subject { server }

    let(:pbs_server) { `qstat -q | awk 'FNR == 2 {print $2}'`.chomp! }

    context 'when local PBS server is found' do
      it { is_expected.to eq(pbs_server) }
    end
  end

  describe "::pbs_connect" do
    subject { conn }

    context "when connecting to local server", :disconnect => true do
      it "provides connection number" do
        expect(subject).to be > 0
      end
      it "doesn't raise an error" do
        expect { subject }.to_not raise_error
      end
    end

    context "when connecting to bad server" do
      let(:server) { 'bad.server' }
      it "raises a PBS error" do
        expect { subject }.to raise_error PBS::PBSError, 'access from host not allowed'
      end
      after { PBS::reset_error }
    end
  end

  describe "::pbs_disconnect" do
    subject { PBS::pbs_disconnect(conn) }

    context "disconnect from local server" do
      let(:conn) { PBS::pbs_connect(server) }
      it "doesn't raise an error" do
        expect { subject }.to_not raise_error
      end
    end

    # The C code doesn't have error checks for disconnecting from bad server
    # it will just segment fault :(
  end
end
