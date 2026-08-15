require "spec_helper"
require "ood_core/job/adapters/coder"
require "ood_core/job/adapters/coder/batch"

describe OodCore::Job::Adapters::Coder::Batch do
  let(:credentials) { double() }

  let(:config) do
    {
      host: "https://coder.example.com",
      token: "fake-token",
      service_user: "ood"
    }
  end

  subject(:batch) { described_class.new(config, credentials) }

  describe "#info" do
    def workspace_info(metadata)
      {
        "id" => "abc-123",
        "workspace_name" => "test-workspace",
        "workspace_owner_name" => "ood",
        "created_at" => "2026-01-01T00:00:00Z",
        "updated_at" => "2026-01-01T00:00:00Z",
        "latest_build" => {
          "id" => "build-1",
          "status" => "running",
          "updated_at" => "2026-01-01T00:00:00Z",
          "resources" => [
            { "name" => "coder_output", "metadata" => metadata }
          ]
        }
      }
    end

    before do
      allow(batch).to receive(:get_build_logs).and_return([])
    end

    it "uses the port supplied in coder_output metadata" do
      allow(batch).to receive(:get_workspace_info).and_return(
        workspace_info(
          [
            { "key" => "floating_ip", "value" => "10.0.0.5" },
            { "key" => "port", "value" => "13337" }
          ]
        )
      )

      expect(batch.info("abc-123").ood_connection_info[:port]).to eq(13337)
    end

    it "defaults to port 80 when no port is supplied" do
      allow(batch).to receive(:get_workspace_info).and_return(
        workspace_info(
          [
            { "key" => "floating_ip", "value" => "10.0.0.5" }
          ]
        )
      )

      expect(batch.info("abc-123").ood_connection_info[:port]).to eq(80)
    end
  end
end
