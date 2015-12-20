class MmmAgent::Host

  require "net/http"
  require "uri"
  require "json"

  attr_accessor :cpu, :gpu
  
  def initialize(log, options)
    # Store for later
    @log = log
    @options = options
    
    # Get informations about the CPU
    @cpu = MmmAgent::Cpu.new
    
    # Get informations about the GPUs (Nvidia only ATM)
    @gpu = Array.new
    (0..nvidia_gpus_count - 1).each do |id|
      @gpu[ id ] = MmmAgent::Gpu.new( id )
    end
    
    # Log hardware informations
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
  
  def get_rig_url
    return @rig_url if !@rig_url.nil?
  
    uri = URI.parse("#{@options.server_url}/rigs.json")
    
    https = Net::HTTP.new(uri.host,uri.port)
    https.use_ssl = true
    
    request = Net::HTTP::Get.new(uri.path)
    request['X-User-Email'] = @options.email
    request['X-User-Token'] = @options.token
    
    response = https.request(request)
    
    if response.code == '200'
      data = JSON.parse(response.body)
      data.each do |rig|
        @rig_url = rig['url'] if rig['hostname'] == @options.hostname
      end
    else
      puts "Error: #{response.body}"
      exit
    end
    
    return @rig_url
  end

end
