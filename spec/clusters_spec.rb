require "spec_helper"
require "pathname"

describe OodCore::Clusters do
  describe "#load_file" do
    context "when loading a valid file" do
      let(:config) { Pathname.pwd + 'spec/fixtures/config/clusters.d/oakley.yml'}

      it "returns an array of OodCore::Cluster" do
        clusters = OodCore::Clusters.load_file(config)
        clusters.each do |cluster|
          expect(cluster).to be_an_instance_of(OodCore::Cluster)
        end
      end
    end

    context "when loading a valid file .yaml" do
      let(:config) { Pathname.pwd + 'spec/fixtures/config/clusters.d/pitzer.yaml'}

      it "returns an array of OodCore::Cluster" do
        clusters = OodCore::Clusters.load_file(config)
        clusters.each do |cluster|
          expect(cluster).to be_an_instance_of(OodCore::Cluster)
        end
      end
    end

    context "when loading directory of cluster configs" do
      let(:config) { Pathname.pwd + 'spec/fixtures/config/clusters.d'}

      it "returns an array of OodCore::Cluster" do
        clusters = OodCore::Clusters.load_file(config)
        clusters.each do |cluster|
          if cluster.id.to_s == 'malformed'
            expect(cluster).to be_an_instance_of(OodCore::InvalidCluster)
          else
            expect(cluster).to be_an_instance_of(OodCore::Cluster)
          end
        end
      end

      it "correctly populates of invalid clusters' id and metadata" do
        clusters = OodCore::Clusters.load_file(config)
        clusters.each do |cluster|
          if cluster.id.to_s == 'malformed'
            id = cluster.id.to_s
            error_msg = cluster.metadata.error_msg.to_s
  
            expect(id).to eql('malformed')
            expect(error_msg).not_to be_empty
          end
        end
      end
    end

    context "when loading an un-readable file" do
      # Use real file so we do not have to mock all of Pathname
      let(:config) { Pathname.pwd + 'spec/fixtures/config/clusters.d/oakley.yml'}

      it "does not raise an error" do
        # Mock file permission ACL
        allow_any_instance_of(Pathname).to receive(:readable?).and_return(false)
        # Throw error if logic is wrong
        allow_any_instance_of(Pathname).to receive(:read).and_raise(Errno::EACCES)

        OodCore::Clusters.load_file(config)
      end
    end

    context "when loading a directory with un-readable files" do
      # Use real file so we do not have to mock all of Pathname
      let(:config) { Pathname.pwd + 'spec/fixtures/config/clusters.d'}

      it "does not raise an error" do
        # Mock file permission ACL
        allow_any_instance_of(Pathname).to receive(:readable?).and_return(false)
        # Throw error if logic is wrong
        allow_any_instance_of(Pathname).to receive(:read).and_raise(Errno::EACCES)

        OodCore::Clusters.load_file(config)
      end
    end

    context "when cluster config does not exist" do
      let(:config) { Pathname.pwd + 'spec/fixtures/config/doesnotexist'}

      it "raises OodCore::ConfigurationNotFound" do
        expect { OodCore::Clusters.load_file(config) }.to raise_error(OodCore::ConfigurationNotFound)
      end
    end

    context "when loading a single malformed .yml" do
      let(:config) { Pathname.pwd + 'spec/fixtures/config/clusters.d/malformed.yml'}

      it "returns an array of OodCore::InvalidCluster" do
        clusters = OodCore::Clusters.load_file(config)
        clusters.each do |cluster|
          expect(cluster).to be_an_instance_of(OodCore::InvalidCluster)
        end
      end

      it "correctly populates id and metadata" do
        clusters = OodCore::Clusters.load_file(config)
        clusters.each do |cluster|
          id = cluster.id.to_s
          error_msg = cluster.metadata.error_msg.to_s

          expect(id).to eql('malformed')
          expect(error_msg).not_to be_empty
        end
      end
    end

  end
end