require "spec_helper"
require "ood_core/batch_connect/templates/vnc"

describe OodCore::BatchConnect::Template do
  it "makes the script file executable before running it" do
    template = described_class.new(
      work_dir: "/tmp",
      script_file: "./script with spaces.sh"
    )

    expect(template.to_s).to include(
      %(bash -c '[[ -x "$1" ]] || chmod +x "$1"; exec "$1"' -- "./script with spaces.sh" &)
    )
  end

  it "does not change permissions for a custom run script" do
    template = described_class.new(
      work_dir: "/tmp",
      run_script: "custom-command"
    )

    expect(template.to_s).to include("custom-command &")
    expect(template.to_s).not_to include("chmod +x")
  end

  it "does not change permissions for an overridden run script" do
    template_class = Class.new(described_class) do
      private
        def run_script
          "custom-command"
        end
    end

    template = template_class.new(work_dir: "/tmp")

    expect(template.to_s).to include("custom-command &")
    expect(template.to_s).not_to include("chmod +x")
  end

  it "preserves the VNC display environment" do
    template = OodCore::BatchConnect::Templates::VNC.new(
      work_dir: "/tmp",
      script_file: "./script.sh"
    )

    expect(template.to_s).to include(
      %(DISPLAY=:${display} bash -c '[[ -x "$1" ]] || chmod +x "$1"; exec "$1"' -- "./script.sh" &)
    )
  end
end
