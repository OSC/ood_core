require "spec_helper"
require "pathname"

def malformed_msg
  "(<unknown>): mapping values are not allowed in this context at line 5 column 8"
end

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
            expect(cluster.valid?).to eql(false)
          else
            expect(cluster).to be_an_instance_of(OodCore::Cluster)
            expect(cluster.valid?).to eql(true)
          end
        end
      end

      it "correctly populates of invalid clusters' id and errors" do
        clusters = OodCore::Clusters.load_file(config)
        clusters.each do |cluster|
          if cluster.id.to_s == 'malformed'
            id = cluster.id.to_s
  
            expect(id).to eql('malformed')
            expect(cluster.errors.size).to eql(1)
            expect(cluster.errors[0]).to eql(malformed_msg)
          else
            expect(cluster.errors).to be_empty
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
          expect(cluster.valid?).to eql(false)
        end
      end

      it "correctly populates id and metadata" do
        clusters = OodCore::Clusters.load_file(config)
        clusters.each do |cluster|
          id = cluster.id.to_s

          expect(id).to eql('malformed')
          expect(cluster.valid?).to eql(false)
          expect(cluster.errors.size).to eql(1)
          expect(cluster.errors[0]).to eql(malformed_msg)
        end
      end
    end

  end
end