require "ood_core/refinements/array_extensions"
require 'pathname'
require 'yaml'

module OodCore
    class AppConfig
        using Refinements::ArrayExtensions

        attr_reader :raw_config

        def initialize
        end

        def load_config
            @raw_config = YAML.load(load_yaml) || {}
        end

        def branding_bg_color
            raw_config.dig('branding', 'bg_color') || '#53565a'
        end

        def branding_link_active_bg_color
            raw_config.dig('branding', 'link_active_bg_color') || '#3b3d3f'
        end

        def branding_navbar_type
            raw_config['navbar_type'] || 'inverse'
        end

        def branding_dashboard_header_logo
            pathname_or_nil(raw_config.dig('branding', 'dashboard_header_logo'))
        end

        def branding_dashboard_logo
            pathname_or_nil(raw_config.dig('branding', 'dashboard_logo'))
        end

        def branding_dashboard_title
            raw_config.dig('branding', 'dashboard_title') || 'Open OnDemand'
        end

        def default_ssh_host
            raw_config['default_ssh_host']
        end

        def disable_safari_basic_auth_warning
            setting = raw_config['disable_safari_basic_auth_warning']
            return true if setting.nil?

            !! setting
        end
        alias_method :disable_safari_basic_auth_warning?, :disable_safari_basic_auth_warning

        def enable_native_vnc
            !! raw_config['enable_native_vnc']
        end
        alias_method :enable_native_vnc?, :enable_native_vnc

        def file_upload_max
            (raw_config['file_upload_max'] || 10485760000).to_i
        end

        def motd_format
            raw_config.dig('motd', 'format')
        end

        def motd_uri
            raw_config.dig('motd', 'uri')
        end

        def announcement_path
            Array.wrap(raw_config['announcement_path'] || []).map do |path|
                Pathname.new(path)
            end
        end

        def app_catalog_url
            raw_config['app_catalog_url']
        end

        # Replaces: app_development
        def show_app_development
            !! raw_config['app_development']
        end
        alias_method :show_app_development?, :show_app_development

        def app_sharing
            !! raw_config['app_sharing']
        end
        alias_method :app_sharing?, :app_sharing

        def dev_ssh_host
            raw_config['dev_ssh_host']
        end

        def user_file_system_locations
            Array.wrap(raw_config['user_file_system_locations'] || []).map do |location|
                Pathname.new(location)
            end
        end

        def links
            raw_config['links'] || {}
        end

        def load_external_bc_config
            setting = raw_config['load_external_bc_config']
            return true if setting.nil?

            !! setting
        end
        alias_method :load_external_bc_config?, :load_external_bc_config

        def load_external_config
            setting = raw_config['load_external_config']
            return true if setting.nil?

            !! setting
        end
        alias_method :load_external_config?, :load_external_config

        def locale
            raw_config['locale'] || 'en'
        end

        def locales_root
            Pathname.new(raw_config['locales_root'] || '/etc/ood/config/locales')
        end

        def quota_path
            Array.wrap(raw_config['quota_path'] || []).map do |path|
                Pathname.new(path)
            end
        end

        def ssh_hosts
            raw_config['ssh_hosts'] || []
        end

        def poll_delay
            (raw_config['poll_delay'] || 10000).to_i
        end

        def show_all_apps_link
            !! raw_config['show_all_apps_link']
        end
        alias_method :show_all_apps_link?, :show_all_apps_link

        def whitelist_path
            raw_config['whitelist_path'] || []
        end

        class Error < StandardError; end

        private

        def load_yaml
            erb_wrapper_path = Pathname.new(ENV['OOD_CONFIG_ERB_WRAPPER'] || '/etc/ood/config/bin/erb_wrapper')
            app_config_path = Pathname.new(ENV['OOD_APP_CONFIG'] || '/etc/ood/config/app_config.yml')
            o, e, s = Open3.capture3(erb_wrapper_path.to_s, app_config_path.to_s)
            s.success? ? o : raise(Error, e)
        end

        def pathname_or_nil(path)
            (path) ? Pathname.new(path) : nil
        end
    end
end