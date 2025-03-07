class OodCore::Job::Adapters::Coder::CoderJobInfo < OodCore::Job::Info
    attr_reader :ood_connection_info
  
    def initialize(options)
      super(**options)
      @ood_connection_info = options[:ood_connection_info]
    end
  end