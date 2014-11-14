describe PBS do
  include PBS

  # methods
  it { should respond_to(:pbs_connect) }
  it { should respond_to(:pbs_default) }
  it { should respond_to(:pbs_deljob) }
  it { should respond_to(:pbs_disconnect) }
  it { should respond_to(:pbs_statfree) }
  it { should respond_to(:pbs_statjob) }
  it { should respond_to(:pbs_statnode) }
  it { should respond_to(:pbs_statque) }
  it { should respond_to(:pbs_statserver) }
  it { should respond_to(:pbs_submit) }
  it { should respond_to(:error) }
  it { should respond_to(:error?) }

  describe "a local PBS server" do
    
  end
end
