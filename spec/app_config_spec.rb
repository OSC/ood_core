require "spec_helper"
require "climate_control"
require "pathname"

def with_modified_env(options, &block)
  ClimateControl.modify(options, &block)
end

describe OodCore::AppConfig do
    subject(:config) { described_class.new }
    let(:default_config_path) { '/etc/ood/config/app_config.yml' }
    let(:default_config_gen_path) { '/etc/ood/config/bin/config_generator' }
    let(:fixture_dir) { Pathname.new(__FILE__).dirname.join('fixtures') }
    let(:alt_config_path) { fixture_dir.join('config/app_config.yml') }
    let(:alt_config_gen_path) { fixture_dir.join('scripts/erb_wrapper.sh') }
    let(:fixture_env) { {
        :OOD_APP_CONFIG => alt_config_path.to_s,
        :OOD_CONFIG_GENERATOR => alt_config_gen_path.to_s
    } }

    context "when OOD_APP_CONFIG is set" do
        it "loads the alternative configuration" do
            with_modified_env fixture_env do
                described_class.load_config
            end
        end
    end

    context "when OOD_APP_CONFIG is not set" do
        it "reads the default configuration file" do
            expect_any_instance_of(Pathname).to receive(:read).and_return('')

            described_class.load_config
        end
    end

    context "when an alternative config path is passed" do
        let(:expected_hash) {{
            :ssh_hosts => [
                {'host_name' => 'Owens', 'ssh_host' => 'owens.osc.edu'},
                {'host_name' => 'Ruby', 'ssh_host' => 'ruby.osc.edu'},
                {'host_name' => 'Pitzer', 'ssh_host' => 'pitzer.osc.edu'}
            ],
            :poll_delay => 5000
        }}
        it "returns the correct values" do
            expect(
                described_class.load_config(
                    fixture_dir.join('config/app_config_minimal.yaml')
                ).to_h
            ).to include(expected_hash)
        end
    end

    context "when no config file is found" do
        it "raises OodCore::AppConfig::Error" do
            expect{described_class.load_config}.to raise_error(OodCore::AppConfig::Error)
        end
    end

    context "when the config_generator exists but is not executable" do
        it "raises an OodCore::AppConfig::Error" do
            expect_any_instance_of(Pathname).to receive(:exist?).and_return(true)
            expect_any_instance_of(Pathname).to receive(:executable?).and_return(false)

            expect{described_class.load_config}.to raise_error(OodCore::AppConfig::Error)
        end
    end

    context "when unused items exist in the config" do
        let(:loaded_yaml) {
            <<~YAML
            ---
            not_an_ondemand_config_key: some unnecessary value
            YAML
        }

        it "does not crash" do
            expect_any_instance_of(Pathname).to receive(:read).and_return(loaded_yaml)

            expect(described_class.load_config.raw_config).to eq({'not_an_ondemand_config_key' => 'some unnecessary value'})
        end
    end

    context "when #to_h is called on a default config" do
        let(:expected_hash) {{
          :announcement_path => [],
          :app_catalog_url => nil,
          :app_sharing => false,
          :app_sharing? => false,
          :branding_bg_color => "#53565a",
          :branding_dashboard_header_logo => nil,
          :branding_dashboard_logo => nil,
          :branding_dashboard_title => "Open OnDemand",
          :branding_link_active_bg_color => "#3b3d3f",
          :branding_navbar_type => "inverse",
          :default_ssh_host => nil,
          :dev_ssh_host => nil,
          :disable_safari_basic_auth_warning => true,
          :disable_safari_basic_auth_warning? => true,
          :enable_native_vnc => false,
          :enable_native_vnc? => false,
          :file_upload_max => 10485760000,
          :links => {},
          :load_external_bc_config => true,
          :load_external_bc_config? => true,
          :load_external_config => true,
          :load_external_config? => true,
          :locale => "en",
          :locales_root => Pathname.new("/etc/ood/config/locales"),
          :motd_format => nil,
          :motd_uri => nil,
          :poll_delay => 10000,
          :quota_path => [],
          :raw_config => {},
          :show_all_apps_link => false,
          :show_all_apps_link? => false,
          :show_app_development => false,
          :show_app_development? => false,
          :ssh_hosts => [],
          :user_file_system_locations => [],
          :whitelist_path => []
        }}

        it "returns the correct Hash" do
            expect(config.to_h).to eq(expected_hash)
        end
    end

    context "when the fixture config is loaded" do
        it "has the correct values" do
            with_modified_env fixture_env do
                config = described_class.load_config

                expect(config.announcement_path).to eq([])
                expect(config.app_catalog_url).to eq(nil)
                expect(config.branding_bg_color).to eq('#6CACE4')
                expect(config.branding_dashboard_header_logo).to eq(nil)
                expect(config.branding_dashboard_logo).to eq(Pathname.new('/public/logo.png'))
                expect(config.branding_dashboard_title).to eq('OSC OnDemand')
                expect(config.branding_link_active_bg_color).to eq('#375C84')
                expect(config.branding_navbar_type).to eq('inverse')
                expect(config.default_ssh_host).to eq('owens.osc.edu')
                expect(config.dev_ssh_host).to eq('ondemand-test.osc.edu')
                expect(config.disable_safari_basic_auth_warning).to eq(true)
                expect(config.disable_safari_basic_auth_warning?).to eq(true)
                expect(config.enable_native_vnc).to eq(true)
                expect(config.enable_native_vnc?).to eq(true)
                expect(config.file_upload_max).to eq(10485760000)
                expect(config.links.is_a? Hash).to be(true)
                expect(config.links.keys.sort).to eq(['Files', 'Jobs', 'Clusters', 'Interactive Apps', 'Help'].sort)
                expect(config.load_external_bc_config).to be(false)
                expect(config.load_external_bc_config?).to be(false)
                expect(config.load_external_config).to be(false)
                expect(config.load_external_config?).to be(false)
                expect(config.locale).to eq('en')
                expect(config.locales_root).to eq(Pathname.new('/etc/ood/config/locales'))
                expect(config.motd_format).to eq('osc')
                expect(config.motd_uri).to eq('file:///etc/motd')
                expect(config.poll_delay).to eq(10000)
                expect(config.quota_path).to eq([
                    Pathname.new('/users/reporting/storage/quota/netapp.netapp-home.ten.osc.edu-users_quota.json'),
                    Pathname.new('/users/reporting/storage/quota/gpfs.project_quota.json'),
                    Pathname.new('/users/reporting/storage/quota/gpfs.scratch_quota.json')
                ])
                expect(config.show_all_apps_link).to be(true)
                expect(config.show_all_apps_link?).to be(true)
                expect(config.show_app_development).to eq(false)
                expect(config.show_app_development?).to eq(false)
                expect(config.ssh_hosts).to eq([])
                expect(config.user_file_system_locations.all?{ |location| location.is_a? Pathname }).to be(true)
                expect(config.user_file_system_locations.is_a? Array).to be(true)
                expect(config.whitelist_path).to eq([])
            end
        end
    end

    context "when a blank config is loaded" do
        it "has the correct defaults" do
            expect(config.announcement_path).to eq([])
            expect(config.app_catalog_url).to eq(nil)
            expect(config.branding_bg_color).to eq('#53565a')
            expect(config.branding_dashboard_header_logo).to eq(nil)
            expect(config.branding_dashboard_logo).to eq(nil)
            expect(config.branding_dashboard_title).to eq('Open OnDemand')
            expect(config.branding_link_active_bg_color).to eq('#3b3d3f')
            expect(config.branding_navbar_type).to eq('inverse')
            expect(config.default_ssh_host).to eq(nil)
            expect(config.dev_ssh_host).to eq(nil)
            expect(config.disable_safari_basic_auth_warning).to eq(true)
            expect(config.disable_safari_basic_auth_warning?).to eq(true)
            expect(config.enable_native_vnc).to eq(false)
            expect(config.enable_native_vnc?).to eq(false)
            expect(config.file_upload_max).to eq(10485760000)
            expect(config.links.is_a? Hash).to be(true)
            expect(config.load_external_bc_config).to be(true)
            expect(config.load_external_bc_config?).to be(true)
            expect(config.load_external_config).to be(true)
            expect(config.load_external_config?).to be(true)
            expect(config.locale).to eq('en')
            expect(config.locales_root).to eq(Pathname.new('/etc/ood/config/locales'))
            expect(config.motd_format).to eq(nil)
            expect(config.motd_uri).to eq(nil)
            expect(config.poll_delay).to eq(10000)
            expect(config.quota_path).to eq([])
            expect(config.show_all_apps_link).to be(false)
            expect(config.show_all_apps_link?).to be(false)
            expect(config.show_app_development).to eq(false)
            expect(config.show_app_development?).to eq(false)
            expect(config.ssh_hosts).to eq([])
            expect(config.user_file_system_locations.empty?).to be(true)
            expect(config.user_file_system_locations.is_a? Array).to be(true)
            expect(config.whitelist_path).to eq([])
        end
    end
end