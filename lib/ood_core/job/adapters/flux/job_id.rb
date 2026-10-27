# Convert Flux job ids to decimal. Flux prints ids in F58 (RFC 19), base58
# with a "ƒ" prefix; OnDemand stores and returns them in decimal.
#
# Written in the compact form so this file never reopens class Flux. It is
# required from inside the Flux class body, after the class exists.
#
# @api private
module OodCore::Job::Adapters::Flux::JobId
  # The base58 alphabet Flux uses for F58 ids (RFC 19)
  F58_ALPHABET = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz".freeze

  # Flux prefixes F58 ids with "ƒ", or "f" when the locale isn't UTF-8
  F58_PREFIX = /\A[ƒf]/.freeze

  # @param id [#to_s] a job id in decimal or F58
  # @return [String] the job id in decimal
  def self.to_decimal(id)
    str = id.to_s.dup.force_encoding(Encoding::UTF_8).strip
    return str if str.match?(/\A\d+\z/)

    unless str.match?(F58_PREFIX)
      raise OodCore::Job::Adapters::Flux::Batch::Error, "unrecognized flux job id: #{str.inspect}"
    end

    digits = str.sub(F58_PREFIX, "")
    number = 0
    digits.each_char do |char|
      value = F58_ALPHABET.index(char)
      raise OodCore::Job::Adapters::Flux::Batch::Error, "unrecognized flux job id: #{str.inspect}" if value.nil?

      number = (number * 58) + value
    end
    number.to_s
  end
end
