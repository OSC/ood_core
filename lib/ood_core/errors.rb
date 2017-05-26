module OodCore
  # Generic {OodCore} exception class
  class Error < StandardError; end

  # Raised when cannot find configuration file specified
  class ConfigurationNotFound < Error; end

  # Raised when adapter not specified in configuration
  class AdapterNotSpecified < Error; end

  # Raised when cannot find adapter specified in configuration
  class AdapterNotFound < Error; end

  # Raised when job adapter encounters an error with resource manager
  class JobAdapterError < Error; end

  # Raised when a job state is set to an invalid option
  class UnknownStateAttribute < Error; end

  # Raised when template not specified in configuration
  class TemplateNotSpecified < Error; end

  # Raised when cannot find template specified in configuration
  class TemplateNotFound < Error; end
end
