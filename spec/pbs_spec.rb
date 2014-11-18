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

  describe "::pbs_default" do
    subject { server }

    let(:pbs_server) { `qstat -q | awk 'FNR == 2 {print $2}'`.chomp! }

    context 'when local PBS server is found' do
      it { is_expected.to eq(pbs_server) }
    end
  end

  describe "::pbs_connect" do
    subject(:conn) { PBS::pbs_connect(server) }

    context "when connecting to local server" do
      it "provides connection number" do
        expect(conn).to be > 0
      end
      it "doesn't raise an error" do
        expect { conn }.to_not raise_error
      end
      after { PBS::pbs_disconnect(conn) }
    end

    context "when connecting to bad server" do
      let(:server) { 'bad.server' }
      it "raises a PBS error" do
        expect { conn }.to raise_error PBS::PBSError, 'access from host not allowed'
      end
      after { PBS::reset_error }
    end
  end
end
