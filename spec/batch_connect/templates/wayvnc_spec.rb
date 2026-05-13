require "spec_helper"
require "ood_core/batch_connect/templates/wayvnc"

describe OodCore::BatchConnect::Templates::WayVNC do
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

    it "includes websocket in the generated connection yaml" do
      expect(rendered).to include("websocket: $websocket")
    end

    it "contains the wayvnc setup block in before_script" do
      expect(rendered).to include(<<~BASH.chomp)
        # Find an available port for wayvnc to listen on. wayvnc serves
        # both VNC and the websocket on this same listener.
        websocket=$(find_port)
        export WAYVNC_WEBSOCKET_PORT="${websocket}"
      BASH
    end

    it "contains the config block with password auth enabled" do
      expect(rendered).to include(<<~BASH.chomp)
        # Write a wayvnc config file that enables password auth
        echo "Writing wayvnc config..."
        (
          umask 077
          cat > "$PWD/wayvnc.conf" <<WAYVNC_CONF
        enable_auth=true
        password=${password}
        relax_encryption=true
        allow_broken_crypto=true
        WAYVNC_CONF
        )
      BASH
    end

    it "contains the wayland attach block in after_script" do
      expect(rendered).to include(<<~BASH.chomp)
        # Wait for the compositor socket before launching wayvnc.
        wayland_socket="${WAYLAND_DISPLAY:-wayland-0}"
        attach_timeout="${WAYVNC_ATTACH_TIMEOUT_SECONDS:-30}"
        wayland_socket_path="${XDG_RUNTIME_DIR}/${wayland_socket}"

        echo "Waiting for wayland socket: ${wayland_socket_path} ..."
        ready=0
      BASH
    end

    it "contains the launch and readiness checks" do
      expect(rendered).to match(%r{echo "Starting wayvnc on \$\{host\}:\$\{WAYVNC_WEBSOCKET_PORT\} attached to \$\{wayland_socket\}\.\.\.".*?WAYLAND_DISPLAY="\$\{wayland_socket\}" \\\nwayvnc \\\n\s+--config="\$PWD/wayvnc\.conf" \\\n\s+--log-level=warning \\\n.*?"ws:0\.0\.0\.0:\$\{WAYVNC_WEBSOCKET_PORT\}" \\\n\s+&> "\$PWD/wayvnc\.log" &\nWAYVNC_PID=\$!}m)
      expect(rendered).to match(%r{WAYVNC_PID=\$!\n\n# Make sure wayvnc actually started up and is listening\.\nwait_until_port_used "localhost:\$\{WAYVNC_WEBSOCKET_PORT\}" 30}m)
    end

    it "cleans up the wayvnc process" do
      expect(rendered).to include("[[ -n ${WAYVNC_PID} ]] && kill -TERM ${WAYVNC_PID} 2>/dev/null")
    end
  end

  context "when custom wayvnc options are provided" do
    subject(:rendered) do
      build_template(
        wayvnc_cmd: "/usr/bin/wayvnc",
        wayvnc_log: "/tmp/custom-wayvnc.log",
        wayvnc_config: "/tmp/custom-wayvnc.conf",
        wayvnc_log_level: "debug",
        wayland_socket: "wayland-3",
        wayvnc_attach_timeout_seconds: "45"
      ).to_s
    end

    it "uses the provided values in generated scripts" do
      expect(rendered).to include(<<~BASH.chomp)
        wayland_socket="wayland-3"
        attach_timeout="45"
      BASH

      expect(rendered).to match(%r{/usr/bin/wayvnc \\\n\s+--config="/tmp/custom-wayvnc\.conf" \\\n\s+--log-level=debug \\\n.*?"ws:0\.0\.0\.0:\$\{WAYVNC_WEBSOCKET_PORT\}" \\\n\s+&> "/tmp/custom-wayvnc\.log" &}m)
    end
  end
end

describe OodCore::BatchConnect::Factory do
  describe ".build" do
    it "builds the wayvnc template from config" do
      template = described_class.build(template: "wayvnc", work_dir: "/tmp/work")

      expect(template).to be_a(OodCore::BatchConnect::Templates::WayVNC)
    end
  end
end