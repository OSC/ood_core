require "spec_helper"
require "climate_control"
require "pathname"

def with_modified_env(options, &block)
  ClimateControl.modify(options, &block)
end

describe OodCore::AppConfig do
    subject(:config) { described_class.new }
    let(:default_config_path) { '/etc/ood/config/app_config.yml' }
    let(:default_erb_wrapper_path) { '/etc/ood/config/bin/erb_wrapper' }
    let(:fixture_dir) { Pathname.new(__FILE__).dirname.join('fixtures') }
    let(:alt_config_path) { fixture_dir.join('config/app_config.yml') }
    let(:alt_erb_wrapper_path) { fixture_dir.join('scripts/erb_wrapper.sh') }
    let(:fixture_env) { {
        :OOD_APP_CONFIG => alt_config_path.to_s,
        :OOD_CONFIG_ERB_WRAPPER => alt_erb_wrapper_path.to_s
    } }

    context "when OOD_APP_CONFIG is set" do
        it "loads the alternative configuration" do
            with_modified_env fixture_env do
                config.load_config
            end
        end
    end

    context "when OOD_APP_CONFIG is not set" do
        it "loads the default configuration" do
            allow(Open3).to receive(
                :capture3
            ).with(
                default_erb_wrapper_path, default_config_path
            ).and_return([
                '---', '', double(:success? => true)
            ])

            config.load_config
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
            allow(Open3).to receive(
                :capture3
            ).with(
                default_erb_wrapper_path, default_config_path
            ).and_return([
                loaded_yaml,'', double(:success? => true)
            ])

            config.load_config
        end
    end

    context "when the fixture config is loaded" do
        it "has the correct values" do
            with_modified_env fixture_env do
                config.load_config

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
            with_modified_env fixture_env do
                allow(Open3).to receive(
                    :capture3
                ).and_return([
                    '---', '', double(:success? => true)
                ])
                config.load_config

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
end