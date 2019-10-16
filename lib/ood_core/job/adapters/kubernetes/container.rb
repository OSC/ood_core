class OodCore::Job::Adapters::Kubernetes::Container
  attr_accessor :image, :command, :port, :name
  
  def initialize(name, image, command = nil, port = nil)
    @name = name
    @image = image
    @command = command
    @port = port
  end

end