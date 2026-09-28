require "spec_helper"
require "open3"
require "ood_core/batch_connect/templates/selkies"

describe OodCore::BatchConnect::Templates::Selkies do
  def build_template(opts = {})
    described_class.new({ work_dir: "/tmp/work" }.merge(opts))
  end

  subject(:template) { build_template }

  describe ".new" do
    it "requires work_dir" do
      expect { described_class.new }.to raise_error(ArgumentError, /Missing argument: work_dir/)
    end
  end

  describe "#to_s" do
    subject(:rendered) { template.to_s }

    it "renders a script bash can parse" do
      _, stderr, status = Open3.capture3("bash", "-n", stdin_data: rendered)
      expect(status).to be_success, stderr
    end

    it "writes only the host, the port, and the session token to the connection file" do
      expect(rendered).to include('echo -e "host: $host\nport: $port\npassword: $password" > "connection.yml"')
    end

    it "picks the port and generates both tokens before the launcher starts" do
      expect(rendered).to include(<<~'BASH'.chomp)
        port=$(find_port "${host}")
        [[ $? -eq 0 ]] || clean_up 1
        password=$(create_passwd "32")
      BASH
      expect(rendered).to include(<<~'BASH'.chomp)
        SELKIES_MASTER_TOKEN=$(create_passwd "32")
        export SELKIES_MASTER_TOKEN
      BASH
    end

    it "passes the master token to containers started with a clean environment" do
      expect(rendered).to include('export APPTAINERENV_SELKIES_MASTER_TOKEN="${SELKIES_MASTER_TOKEN}"')
      expect(rendered).to include('export SINGULARITYENV_SELKIES_MASTER_TOKEN="${SELKIES_MASTER_TOKEN}"')
    end

    it "starts Selkies for the portal's proxy, without a login or TLS of its own" do
      expect(rendered).to include(<<~'BASH'.chomp)
        local args=(--public --port="${port}" --enable-basic-auth=false --enable-https=false --allowed-origins='*')
      BASH
      expect(rendered).to include('exec selkies-session "${args[@]}"' + "\n")
    end

    it "runs the app's script as the desktop, and ends the session when it returns" do
      expect(rendered).to include(<<~'BASH'.chomp)
        args+=(--session="bash -c $(printf '%q' "$1; kill -TERM ${launcher_pid}")")
      BASH
      expect(rendered).to include(%(selkies_launch \\"./script.sh\\" &\n))
    end

    it "waits for Selkies to answer, and gives up once the launcher exits or the time passes" do
      expect(rendered).to include('selkies_deadline=$((SECONDS + ${SELKIES_TIMEOUT_SECONDS:-120}))')
      expect(rendered).to include(%q{until curl -fs -o /dev/null --noproxy '*' --max-time 2 "http://${host}:${port}/api/health"; do})
      expect(rendered).to include('if ! kill -0 "${SCRIPT_PID}" 2>/dev/null || (( SECONDS >= selkies_deadline )); then')
    end

    it "provisions the session token with both tokens off the command line and away from proxies" do
      expect(rendered).to include(<<~'BASH'.chomp)
        curl -fsS -o /dev/null --max-time 10 --config - <<SELKIES_TOKENS || clean_up 1
        url = "http://${host}:${port}/api/tokens"
        noproxy = "*"
        header = "Authorization: Bearer ${SELKIES_MASTER_TOKEN}"
        header = "Content-Type: application/json"
        data = {"${password}":{"role":"controller","slot":1}}
        SELKIES_TOKENS
      BASH
    end

    it "provisions the session token before it writes the connection file" do
      expect(rendered.index("SELKIES_TOKENS\necho")).to be < rendered.index("# Create the connection yaml file")
    end

    it "stops the launcher when the job cleans up" do
      expect(rendered).to include('if [[ -n "${SCRIPT_PID}" ]] && kill -TERM "${SCRIPT_PID}" 2>/dev/null; then')
    end
  end

  context "when the app sets a timeout for its script" do
    subject(:rendered) { build_template(timeout: "30").to_s }

    it "times out the desktop" do
      expect(rendered).to include(%(selkies_launch timeout\\ 30\\ \\"./script.sh\\" &\n))
    end
  end

  context "when the app names an installed desktop" do
    subject(:rendered) { build_template(selkies_session: "startxfce4 --replace").to_s }

    it "starts that desktop as one argument, in place of the app's script" do
      expect(rendered).to include(%q{--allowed-origins='*' --session=startxfce4\ --replace)})
      expect(rendered).to include("\nselkies_launch &\n")
    end

    it "starts that desktop in the home" do
      expect(rendered).to include("cd ~ || exit 1\n")
    end
  end

  context "when the app asks for the default desktop" do
    subject(:rendered) { build_template(selkies_session: "").to_s }

    it "starts the launcher without a session" do
      expect(rendered).to include(%q{--allowed-origins='*')})
      expect(rendered).to include("\nselkies_launch &\n")
    end
  end

  context "when custom options are provided" do
    subject(:rendered) do
      build_template(
        selkies_cmd: "apptainer exec --nv /opt/selkies.sif selkies-session",
        selkies_args: "--wayland",
        selkies_timeout_seconds: "300",
        password_size: 48
      ).to_s
    end

    it "uses the provided values in the generated script" do
      expect(rendered).to include('exec apptainer exec --nv /opt/selkies.sif selkies-session "${args[@]}" --wayland')
      expect(rendered).to include("selkies_deadline=$((SECONDS + 300))")
      expect(rendered).to include('password=$(create_passwd "48")')
    end
  end
end

describe OodCore::BatchConnect::Factory do
  describe ".build" do
    it "builds the selkies template from config" do
      template = described_class.build(template: "selkies", work_dir: "/tmp/work")

      expect(template).to be_a(OodCore::BatchConnect::Templates::Selkies)
    end
  end
end
