# Helpers for parsing Slurm's output formats: GRES and TRES strings, memory
# sizes, and durations.
#
# Both Slurm and Slurm::Batch need these, so each includes this module.
# Slurm also extends it, which keeps the Slurm.gpus_from_gres(...) form
# working for existing callers.
#
# Written in the compact form so this file never reopens class Slurm. It is
# required from inside the Slurm class body, after the class exists.
module OodCore::Job::Adapters::Slurm::Parsing
  UNIT_FACTORS = {
    'K' =>                 1_024,
    'M' =>             1_048_576,
    'G' =>         1_073_741_824,
    'T' =>     1_099_511_627_776,
    'P' => 1_125_899_906_842_624
  }

  # Get integer representing the number of gpus used by a node or job,
  # calculated from gres string
  # @return [Integer] the number of gpus in gres
  def gpus_from_gres(gres)
    gres.to_s.scan(/gpu[s:]*[\w()-]*[=:]?(\d+)(?:[(,]|$)/).flatten.map(&:to_i).sum
  end

  # Get a hash of gpu types to allocated count, computed from a tres string.
  # TRES may report GPUs as an untyped rollup ('gres/gpu=2'), as typed
  # entries ('gres/gpu:a100=2'), or both. Only typed entries carry a type,
  # so untyped ones are excluded.
  # @return [Hash] gpu types and counts, e.g. { 'a100' => 2 }
  def gpu_types_from_tres(tres)
    tres.to_s.scan(%r{(?:^|,)(?:gres/)?gpu:([\w()-]+)=(\d+)(?=,|$)})
        .map { |type, count| [type, count.to_i] }.to_h
  end

  # Get integer representing memory in bytes, computed from tres-alloc string
  # @return [Integer] the number of bytes of allocated memory
  def memory_from_tres(tres)
    match = tres.to_s.match(/(?:^|,)mem=([\d.]+)([KMGTP]?)(?:,|$)/)
    return unless match

    memory = (UNIT_FACTORS.fetch(match[2], 1) * match[1].to_f).to_i
    memory unless memory == 0
  end

  # Get integer representing the number of gpus, computed from a tres string.
  # TRES may report GPUs twice - a typed entry and an untyped rollup, e.g.
  # 'gres/gpu:a100=16,gres/gpu=16' - so summing every match double counts.
  # The rollup is authoritative; typed entries are a fallback for the case
  # where no rollup is present.
  # @return [Integer] the number of gpus in tres
  def gpus_from_tres(tres)
    rollup = tres.to_s.match(%r{(?:^|,)(?:gres/)?gpu=(\d+)(?:,|$)})
    return rollup[1].to_i if rollup

    tres.to_s.scan(%r{(?:^|,)(?:gres/)?gpu:[\w()-]+=(\d+)(?=,|$)}).flatten.map(&:to_i).sum
  end

  # Convert a Slurm duration string to seconds.
  # Handles both "HH:MM:SS" and "D-HH:MM:SS" forms.
  # @return [Integer] the duration in seconds
  def duration_in_seconds(time)
    return 0 if time.nil?
    time, days = time.split("-").reverse
    days.to_i * 24 * 3600 +
      time.split(':').map { |v| v.to_i }.inject(0) { |total, v| total * 60 + v }
  end
end
