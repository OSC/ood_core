class CredentialsInterface
  def load_credentials
    raise NotImplementedError, "#{self.class} must implement #{__method__}"
  end

  def generate_credentials
    raise NotImplementedError, "#{self.class} must implement #{__method__}"
  end

  def destroy_credentials
    raise NotImplementedError, "#{self.class} must implement #{__method__}"
  end
  def save_credentials
    raise NotImplementedError, "#{self.class} must implement #{__method__}"
  end
end