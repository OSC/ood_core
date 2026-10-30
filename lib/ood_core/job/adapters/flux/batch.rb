require "json"
require "open3"
require "ood_core/job/adapters/helper"

# Object used for simplified communication with Flux: runs the flux CLI,
# locally or over ssh on a submit host, and parses its JSON.
#
# Written in the compact form, like the LSF and SGE adapters' batch.rb, so
# this file never reopens class Flux. It is required from inside the Flux
# class body, after the class exists.
#
# @api private
class OodCore::Job::Adapters::Flux::Batch
  # The path to the Flux client installation binaries
  # @return [Pathname, nil]
  attr_reader :bin

  # Optional overrides for Flux client executables
  # @example
  #  {'flux' => '/usr/local/bin/flux'}
  # @return Hash<String, String>
  attr_reader :bin_overrides

  # The login node where commands are run via ssh
  # @return [String]
  attr_reader :submit_host

  # Whether to use strict host checking when ssh to submit_host
  # @return [Bool]
  attr_reader :strict_host_checking

  # URI of the Flux instance, or nil for the system instance
  # @return [String, nil]
  attr_reader :flux_uri

  # The root exception class that all Flux-specific exceptions inherit
  # from
  class Error < StandardError; end

  def initialize(bin: nil, bin_overrides: {}, submit_host: "", strict_host_checking: true, flux_uri: nil)
    @bin                  = Pathname.new(bin.to_s)
    @bin_overrides        = bin_overrides
    @submit_host          = submit_host.to_s
    @strict_host_checking = strict_host_checking
    @flux_uri             = flux_uri && flux_uri.to_s
  end

  # Submit a batch script on stdin
  # @param str [#to_s] the script content
  # @param args [Array<#to_s>] arguments to `flux batch`
  # @return [String] the job id, in decimal
  def submit_string(str, args: [])
    out = call("batch", *args, stdin: str.to_s)
    OodCore::Job::Adapters::Flux::JobId.to_decimal(out)
  end

  # Get the json description of one job
  # @param id [#to_s] the job id
  # @return [Hash] the job, with symbol keys
  def get_job(id)
    out = call("jobs", "--json", id.to_s)
    parse_jobs(out).first
  end

  # Get the json descriptions of active jobs
  # @param owner [#to_s, nil] limit to this user; nil means all users
  # @return [Array<Hash>] the jobs, with symbol keys
  def get_jobs(owner: nil)
    args = owner.nil? ? ["-A"] : ["-u", owner.to_s]
    out = call("jobs", "--json", *args)
    parse_jobs(out)
  end

  def hold_job(id)
    call("job", "urgency", id.to_s, "hold")
  end

  def release_job(id)
    call("job", "urgency", id.to_s, "default")
  end

  def delete_job(id)
    call("cancel", id.to_s)
  end

  private

  # `flux jobs --json ID` prints one job object. Without an id it
  # prints {"jobs": [...]}.
  def parse_jobs(out)
    return [] if out.strip.empty?

    data = JSON.parse(out, symbolize_names: true)
    data.key?(:jobs) ? data[:jobs] : [data]
  rescue JSON::ParserError => e
    raise Error, "could not parse flux output: #{e.message}"
  end

  # Call a flux subcommand
  def call(subcommand, *args, stdin: "")
    cmd = OodCore::Job::Adapters::Helper.bin_path("flux", bin, bin_overrides)
    args = [subcommand] + args.map(&:to_s)

    env = {}
    env["FLUX_URI"] = flux_uri if flux_uri

    cmd, args = OodCore::Job::Adapters::Helper.ssh_wrap(submit_host, cmd, args, strict_host_checking, env, bin_overrides)
    o, e, s = Open3.capture3(env, cmd, *(args.map(&:to_s)), stdin_data: stdin.to_s)

    # Flux writes UTF-8 whatever the locale is. F58 ids start with
    # "ƒ", and they show up in error messages too.
    raise Error, utf8(e) unless s.success?

    utf8(o)
  end

  def utf8(str)
    str.dup.force_encoding(Encoding::UTF_8)
  end
end
