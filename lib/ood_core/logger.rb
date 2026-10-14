require 'logger'

module OodCore
  # A direct attribute on OodCore allowing for blanket availability
  # as well as easy access from downstream initializers
  class << self
    attr_writer :logger

    def logger
      @logger ||= Logger.new($stderr, level: Logger::INFO, progname: 'ood_core')
    end
  end
end
