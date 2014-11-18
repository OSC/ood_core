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

  describe "::pbs_default" do
    subject { PBS::pbs_default() }

    let(:pbs_server) { `qstat -q | awk 'FNR == 2 {print $2}'`.chomp! }

    context 'when local PBS server is found' do
      it { is_expected.to eq(pbs_server) }
    end
  end
end
