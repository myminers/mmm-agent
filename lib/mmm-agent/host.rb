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
      @gpu[ id ] = MmmAgent::Gpu.new( id, @log )
    end
    
    # Create MiningOperation object
    @mining_operation = MmmAgent::MiningOperation.new(log, self)
    
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
  
  def update_rig_mining_operation
    data = @server.get(get_rig_url)
    if data['rig']['what_to_mine'].nil?
      @log.info "No mining operation. Go configure your rig on #{@options.server_url}"
      return
    end
    @mining_operation.update(data['rig']['what_to_mine'])
  end
  
  def keep_mining_operation_up_to_date
    while true
      begin
        sleep 600
        @log.info "Getting best mining operation from server"
        update_rig_mining_operation
      rescue StandardError => e
        @log.error "Error contacting mmm-server: #{e.to_s}"
      end
    end
  end
  
  def send_statistics_every_minute
    while true
      sleep 60
      hashrate = 0
      power_draw = 0
      @gpu.each do |g|
        hashrate += g.hashrate.avg.to_i
        power_draw += g.power_draw.avg.to_i
      end
      @log.info "Uploading performance statistics: #{hashrate}H/s, #{power_draw}W"

      #TODO Flush stats
      #TODO send stats to server
    end
  end
  
  def start_mining
    # Get the first mining operation we will be working on
    update_rig_mining_operation
    
    # Keep updating it periodicaly from the server
    Thread.new{keep_mining_operation_up_to_date}
    
    # Send statistics to the server
    Thread.new{send_statistics_every_minute}

    # Run the miner command in the background
    @mining_operation.run_miner
  end

end
