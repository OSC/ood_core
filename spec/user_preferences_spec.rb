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

    it "loads preferences" do
      with_modified_env OOD_PREFERENCES_FILE: preferences_file do
        prefs = OodCore::UserPreferences.new.preferences
        expect(prefs.to_h).to eq(new_preferences)
      end
    end

    it "returns preferences for a single app" do
      with_modified_env OOD_PREFERENCES_FILE: preferences_file do
        prefs = OodCore::UserPreferences.new.preferences(app: 'files')
        expect(prefs.to_h).to eq(files_preferences)
      end
    end

    it "returns empty hash for undefined app" do
      with_modified_env OOD_PREFERENCES_FILE: preferences_file do
        prefs = OodCore::UserPreferences.new.preferences(app: 'new-app-no-configs')
        expect(prefs.to_h).to eq({})
      end
    end

    it "always returns at least an empty hash" do
      with_modified_env OOD_PREFERENCES_FILE:  "/dev/null" do
        prefs = OodCore::UserPreferences.new.preferences
        expect(prefs.to_h).to eq({})
      end
    end
  end
end
