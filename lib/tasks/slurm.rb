# frozen_string_literal: true

require_relative '../ood_core'
require_relative '../ood_core/job/adapters/slurm'

namespace :slurm do

  desc 'Get squeue output in the format this gem expects'
  task :squeue do
    fields = OodCore::Job::Adapters::Slurm::Batch.new.all_squeue_fields
    args = OodCore::Job::Adapters::Slurm::Batch.new.squeue_args(options: fields.values)

    single_job = `squeue #{args.join(' ')}`.split("\n")[0...2]

    puts single_job
  end
end
