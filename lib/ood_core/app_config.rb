require "ood_core/refinements/array_extensions"
require 'pathname'
require 'yaml'

module OodCore
    class AppConfig
        using Refinements::ArrayExtensions

        attr_reader :raw_config

        def self.load_config(app_config_path=nil)
            AppConfig.new(load_yaml(app_config_path) || {})
        end

        def initialize(opts={})
            @raw_config = opts
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

        def to_h
            @to_h ||= Hash[
                AppConfig.instance_methods(false).select do |mthd|
                    # Don't recurse
                    ! [:config, :to_h].include? mthd
                end.sort.map do |mthd|
                    [mthd, self.send(mthd)]
                end
            ]
        end
        alias_method :config, :to_h

        class Error < StandardError; end

        private

        def self.load_yaml(app_config_path)
            config_generator_path = Pathname.new(ENV['OOD_CONFIG_GENERATOR'] || '/etc/ood/config/bin/config_generator')
            app_config_path = Pathname.new(app_config_path || ENV['OOD_APP_CONFIG'] || '/etc/ood/config/app_config.yml')

            if config_generator_path.exist?
                raise Error, "Config generator detected at #{config_generator_path}, but it is not executable" unless config_generator_path.executable?
                o, e, s = Open3.capture3(config_generator_path.to_s, app_config_path.to_s)
                s.success? ? YAML.load(o) : raise(Error, e)
            else
                YAML.load(app_config_path.read)
            end
        rescue StandardError => e
            raise Error, e.message
        end

        def pathname_or_nil(path)
            (path) ? Pathname.new(path) : nil
        end
    end
end