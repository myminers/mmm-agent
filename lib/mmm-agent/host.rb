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
    
    # Create MiningOperation object
    @mining_operation = MmmAgent::MiningOperation.new(log)
    
    # Log hardware informations
    @log.info "Hostname is #{options.hostname}"
    @log.info "Found #{@cpu.human_readable}"
    @log.info "Found #{@gpu.size} GPUs:"
    @gpu.each do |gpu|
      log.info "#{gpu.model} (#{gpu.uuid})"
    end

    # Get a connection to the mmm-server
    @server = MmmAgent::ServerConnection.new(@options,@log)
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
    data.each do |rig|
      if rig['hostname'] == @options.hostname
        uri = URI::parse(rig['url'])
        @rig_url = uri.path
      end
    end
    @rig_url = register_rig if @rig_url.nil?
    return @rig_url
  end
  
  def register_rig
    @log.info "Creating the Rig on mmm-server"
    newRig = {
      :hostname => @options.hostname,
      :power_price => 0,
      :power_currency => 'USD'
    }
    data = @server.post('/rigs.json', newRig)
    id = data['rig']['id']['$oid']
    "/rigs/#{id}.json"
  end
  
  def get_rig_mining_operation
    data = @server.get(get_rig_url)
    if data['rig']['what_to_mine'].nil?
      @log.info "No mining operation. Go configure your rig on #{@options.server_url}"
      return "Nothing to do"
    end
    @mining_operation.update(data['rig']['what_to_mine'])
    @mining_operation.readable_command
  end

end
