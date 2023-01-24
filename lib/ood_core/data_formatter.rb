module OodCore
  module DataFormatter
    # Determine whether to upcase account strings when returning adapter#accounts
    def upcase_accounts?
      env_var = ENV['OOD_UPCASE_ACCOUNTS']

      if env_var.nil? || env_var.to_s.downcase == 'false'
        false
      else
        true
      end
    end
  end
end