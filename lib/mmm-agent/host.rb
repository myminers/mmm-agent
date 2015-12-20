class MmmAgent::Host

  attr_accessor :cpu, :gpu
  
  def initialize(log, options)
    @log = log
    @options = options
    
    @cpu = MmmAgent::Cpu.new
    @gpu = Array.new
    (0..nvidia_gpus_count - 1).each do |id|
      @gpu[ id ] = MmmAgent::Gpu.new( id )
    end
    
    log.info "Hostname is #{options.hostname}"
    log.info "Found #{@cpu.human_readable}"
    log.info "Found #{@gpu.size} GPUs:"
    @gpu.each do |gpu|
      log.info "#{gpu.model} (#{gpu.uuid})"
    end
  end

  def nvidia_gpus_count
    return @nvidia_gpus_count if @nvidia_gpus_count
    @nvidia_gpus_count = `lspci | grep VGA | grep -c NVIDIA`.to_i
  end
  
  def has_nvidia_gpus?
    nvidia_gpus_count > 0
  end

end
