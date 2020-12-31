require "spec_helper"
require "ood_core/user_preferences"

describe OodCore::UserPreferences do

  let(:preferences_file) { "spec/fixtures/config/preferences/user.yml" }

  let(:old_preferences){{
    'dashboard' => {
        'some_thing'    => 'yesPlease!',
        'show_this'     => false,
        'favorite_apps' => [ 'one', 'two' ]
    }
  }}

  let(:files_preferences){{
    'favorite_dirs' => ['/home', '/project', '/home/ondemand/dev']
  }}

  let(:new_preferences){{
    'dashboard' => {
        'some_thing'    => 'yesPlease!',
        'show_this'     => true,
        'favorite_apps' => ['one', 'two', 'three']
    },
    'files' => files_preferences,
  }}

  describe "#preferences" do

    before(:each) do
      # nil out preferences before each test
      OodCore::UserPreferences.instance_variable_set(:@_pref, nil)
    end

    it "loads preferences" do
      with_modified_env OOD_PREFERENCES_FILE: preferences_file do
        prefs = OodCore::UserPreferences.preferences
        expect(prefs.to_h).to eq(new_preferences)
      end
    end

    it "re-loads preferences" do
      Tempfile.create do |cfgfile|
        with_modified_env OOD_PREFERENCES_FILE: cfgfile.path do
          # tmpfile here is trouble to re-write so just close it and use File APIs
          cfgfile.close

          File.open(cfgfile.path, 'w') { |f| f.write(old_preferences.to_yaml) }

          prefs = OodCore::UserPreferences.preferences(reload: true)
          expect(prefs.to_h).to eq(old_preferences)

          File.open(cfgfile.path, 'w+') { |f| f.write(new_preferences.to_yaml) }

          prefs = OodCore::UserPreferences.preferences(reload: true)
          expect(prefs.to_h).to eq(new_preferences)
        end
      end
    end

    it "returns preferences for a single app" do
      with_modified_env OOD_PREFERENCES_FILE: preferences_file do
        prefs = OodCore::UserPreferences.preferences(app: 'files')
        expect(prefs.to_h).to eq(files_preferences)
      end
    end

    it "always returns at least an empty hash" do
      with_modified_env OOD_PREFERENCES_FILE:  "/dev/null" do
        prefs = OodCore::UserPreferences.preferences
        expect(prefs.to_h).to eq({})
      end
    end
  end
end