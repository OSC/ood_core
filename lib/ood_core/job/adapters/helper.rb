module OodCore
  module Job
    module Adapters
      class Helper
        def self.bin_path(cmd, std_bin, custom_bin)
          custom_bin.fetch(cmd.to_s) { std_bin.join(cmd.to_s).to_s }
        end
      end
    end
  end
end