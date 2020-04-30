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
    attr_accessor :name, :image, :command, :port, :env, :memory, :cpu, :working_dir

    def initialize(
        name, image, command: [], port: nil, env: [], memory: "4Gi", cpu: "1",
        working_dir: ""
      )
      raise ArgumentError, "containers need valid names and images" unless name && image

      @name = name
      @image = image
      @command = command.nil? ? [] : command
      @port = port&.to_i
      @env = env.nil? ? [] : env
      @memory = memory.nil? ? "4Gi" : memory
      @cpu = cpu.nil? ? "1" : cpu
      @working_dir = working_dir.nil? ? "" : working_dir
    end

    def ==(other)
      name == other.name &&
        image == other.image &&
        command == other.command &&
        port == other.port &&
        env == other.env &&
        memory == other.memory &&
        cpu == other.cpu &&
        working_dir == other.working_dir
    end

  end

  class PodSpec
    attr_accessor :container, :init_containers
    def initialize(container, init_containers: nil)
      @container = container
      @init_containers = init_containers
    end
  end
  
end