module OodCore
  class UserPreferences
    require 'yaml'

    class << self

      def preferences(app: nil, reload: false)
        app.nil? ? _prefs(reload: reload) : _prefs(reload: reload).fetch(app, {})
      end

      def preferences_file
        pf = ENV['OOD_PREFERENCES_FILE'] || "#{Dir.home}/.config/ondemand/ondemand.yml"
        Pathname.new(pf.to_s).expand_path
      end

      private

      @_prefs = nil

      def _prefs(reload: false)
        return @_prefs if !reload && !@_prefs.nil?

        @@_prefs = begin
          if preferences_file.file? && preferences_file.readable?
            YAML.safe_load(preferences_file.read).to_h
          else
            {}
          end
        rescue
          @_prefs = {}
        end
      end
    end
  end
end
