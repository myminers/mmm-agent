require 'uri'

class MmmAgent::Host

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
    @log.info "Hostname is #{options.hostname}"
    @log.info "Found #{@cpu.human_readable}"
    @log.info "Found #{@gpu.size} GPUs:"
    @gpu.each do |gpu|
      log.info "#{gpu.model} (#{gpu.uuid})"
    end

    # Get a connection to the mmm-server
    @server = MmmAgent::ServerConnection.new(@options)
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
  
    data = @server.get('/rigs.json')
    if data.code == '200'
      data.body.each do |rig|
        if rig['hostname'] == @options.hostname
          uri = URI::parse(rig['url'])
          @rig_url = uri.path
        end
      end
    else
      puts "Error #{data.code}: #{data.body}"
      exit
    end
    @rig_url = register_rig if @rig_url.nil?
    return @rig_url
  end
  
  def register_rig
    newRig = {
      :hostname => @options.hostname,
      :power_price => 0,
      :power_currency => 'USD'
    }
    data = @server.post('/rigs.json', newRig)
    if data.code == '201' # Created
      id = data.body['rig']['id']['$oid']
      return "/rigs/#{id}.json"
    else
      puts "Error #{response.code}: #{response.body}"
      exit
    end
  end

end
