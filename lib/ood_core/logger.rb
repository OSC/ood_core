require 'logger'

module OodCore
  # A direct attribute on OodCore allowing for blanket availability
  # as well as easy access from downstream initializers
  class << self
    attr_writer :logger

    def logger
      @logger ||= ::Logger.new($stderr, level: ::Logger::WARN)
    end

    # Label lives in the message so any logger the host app swaps in still works
    def log(level, message = nil, &block)
      if block_given?
        logger.public_send(level, 'ood_core') { yield }
      else
        logger.public_send(level, 'ood_core') { "#{message}" }
      end
    end
  end
end
