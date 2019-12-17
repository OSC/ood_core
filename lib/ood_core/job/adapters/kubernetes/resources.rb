module OodCore::Job::Adapters::Kubernetes::Resources

  class ConfigMap
    attr_accessor :name, :filename, :data

    def initialize(name, filename, data)
      @name = name
      @filename = filename
      @data = data
    end
  end

  class Container
    attr_accessor :name, :image, :command, :port
    def initialize(name, image, command = nil, port = nil)
      @name = name
      @image = image
      @command = command
      @port = port
    end
  end

  class PodSpec
    attr_accessor :container, :init_containers
    def initialize(container, init_containers = nil)
      @container = container
      @init_containers = init_containers
    end
  end
end