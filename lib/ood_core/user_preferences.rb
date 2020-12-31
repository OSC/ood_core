module OodCore
  class UserPreferences
    require 'yaml'

    def preferences_file
      @preferences_file ||= begin
        pf = ENV['OOD_PREFERENCES_FILE'] || "#{Dir.home}/.config/ondemand/ondemand.yml"
        Pathname.new(pf.to_s).expand_path
      end
    end

    def preferences(app: nil)
      app.nil? ? _prefs : _prefs.fetch(app, {})
    end

    private

    def _prefs
      @_prefs ||= begin
        if preferences_file.file? && preferences_file.readable?
          YAML.safe_load(preferences_file.read).to_h
        else
          {}
        end
      rescue => e
        puts "#{e.message}"
        @_prefs = {}
      end
    end
  end
end
