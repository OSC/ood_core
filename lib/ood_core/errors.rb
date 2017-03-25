module OodCore
  # Generic {OodCore} exception class
  class Error < StandardError; end

  # Raised when cannot find configuration file specified
  class ConfigurationNotFound < Error; end

  # Raised when adapter not specified in configuration
  class AdapterNotSpecified < Error; end

  # Raised when cannot find adapter specified in configuration
  class AdapterNotFound < Error; end

  # Raised when job adapter encounters an error when dealing with resource
  # manager
  class JobAdapterError < Error; end
end
