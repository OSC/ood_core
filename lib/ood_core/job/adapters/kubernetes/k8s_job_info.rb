# An object that describes a submitted kubernetes job with extended information
class OodCore::Job::Adapters::Kubernetes::K8sJobInfo < OodCore::Job::Info
  attr_reader :ood_connection_info

  def initialize(ood_connection_info: {}, **options)
    super(options)
    @ood_connection_info = ood_connection_info
  end
end
