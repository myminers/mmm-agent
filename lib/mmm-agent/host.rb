require 'uri'
require 'pp'

class MmmAgent::Host

  attr_accessor :cpu, :gpu
  
  def initialize(options)
    # Store for later
    @options = options
        
    # Get a connection to the mmm-server
    @server = MmmAgent::ServerConnection.new(@options)

    # Register the rig on mmm-server if needed
    @rig_url  = get_rig_url
    Log.info "#{options.hostname}'s URL is #{@rig_url}"
    @rig_data = get_rig_data

    set_version_number

    # Get informations about the CPU
    # @cpu = MmmAgent::Cpu.new
    # @cpu.register_if_needed(@rig_data, @server)
    
    # Get informations about the GPUs (Nvidia only ATM)
    @gpu = Array.new
    (0..nvidia_gpus_count - 1).each do |id|
      @gpu[id] = MmmAgent::Gpu.new( id )
      @gpu[id].register_if_needed(@rig_data, @server)
    end

    register_miners

    # Reload rig data after everything is registered
    @rig_data = get_rig_data
  end

  def nvidia_gpus_count
    return @nvidia_gpus_count if @nvidia_gpus_count
    @nvidia_gpus_count = `lspci | grep VGA | grep -c NVIDIA`.to_i
  end
  
  def has_nvidia_gpus?
    nvidia_gpus_count > 0
  end

  def set_version_number
    if @rig_data['rig']['agent_version'] != MmmAgent.version
      Log.notice("Looks like mmm-server doesn't know we updated the agent, let's tell them...")
      @server.patch(@rig_url, {'rig' => {'agent_version' => MmmAgent.version}})
    end
  end

  def get_rig_url
    rigs = @server.get('/rigs.json')
    rigs.each do |rig|
      return rig['url'] if rig['hostname'] == @options.hostname
    end
    register_rig
  end
  
  def register_rig
    Log.notice "Creating #{@options.hostname} on mmm-server"
    newRig = {
      :hostname       => @options.hostname,
      :power_price    => 0,
      :power_currency => 'USD',
      :agent_version  => MmmAgent.version
    }
    data = @server.post('/rigs.json', newRig)
    "/rigs/#{data['rig']['id']}.json"
  end

  def get_rig_data
    return @server.get(@rig_url)
  end

  def register_miners
    # Make sure mmm-server knows about all our miners
    miners = @server.get(@rig_data['rig']['add_miner']['miner_release_list'])
    miners.each do |miner|
      if system("which #{miner['name']} > /dev/null 2>&1")
        if !registered_miners.include?(miner['name'])
          Log.notice("#{miner['name']} is missing, registering it on mmm-server")
          @server.patch(@rig_data['rig']['add_miner']['url'], {'rig' => {'miner_release_ids' => miner['id']}})
        end
      end
    end

    # Make sure we really have the miners mmm-server thinks we have (human error in the web interface)
    @rig_data['rig']['miners'].each do |miner|
      if !system("which #{miner['name']} > /dev/null 2>&1")
        puts "Error: #{miner['name']} is missing. Check your configuration and relaunch mmm-agent."
        exit
      end
    end
  end

  def registered_miners
    miners = Array.new
    @rig_data['rig']['miners'].each do |miner|
      miners << miner['name']
    end
    miners
  end

  def update_rig_mining_operations
    data = @server.get(get_rig_url)
    data['rig']['hardware'].each do |hardware|
      slot = hardware['slot']
      if hardware['what_to_mine'].nil?
        Log.warning "No mining operation for GPU##{slot}. Go configure your rig on #{@options.server_url}"
        return data
      end
      @gpu[slot].mining_operation.update(hardware)
    end
    data
  end
  
  def keep_mining_operation_up_to_date(stats_url)
    while true
      begin
        sleep 900
        send_statistics(stats_url)
        clear_statistics
        Log.info "Getting best mining operation from server"
        stats_url = update_rig_mining_operation
      rescue StandardError => e
        Log.warning "Error contacting mmm-server: #{e.to_s}"
      end
    end
  end

  def send_statistics(stats_url)
    stats = {
      :rate         => get_hashrate,
      :power_usage  => get_power_usage
    }
    Log.notice "Sending stats: #{stats[:rate]} H/s at #{stats[:power_usage]} W"
    @server.put(stats_url, stats) unless stats[:rate] == 0
  end
  
  def clear_statistics
    Log.info "Clearing statistics for the next mining round"
    @gpu.each do |g|
      g.clear_statistics
    end    
  end
  
  def start_mining
    # Get the first mining operation we will be working on
    @rig_data = update_rig_mining_operations

    # Start the miners
    @rig_data['rig']['hardware'].each do |hardware|
      if hardware['hardware_type'] == 'gpu'
        slot = hardware['slot'].to_i
        Thread.new { @gpu[slot].mining_operation.run_miner }
      end
    end

    # Monitor miners and keep in sync with the server
    while true
      begin
        sleep 60
        @rig_data['rig']['hardware'].each do |hardware|
          if hardware['hardware_type'] == 'gpu' and !hardware['mining_log'].nil?
            slot = hardware['slot'].to_i
            @gpu[slot].send_statistics( @server, hardware['mining_log']['url'] )
          end
        end
        @rig_data = update_rig_mining_operations
      rescue StandardError => e
        Log.warning "Error contacting mmm-server: #{e.to_s}"
        Log.warning e.backtrace.map {|line| "  #{line}"}
      end
    end
  end

  private

    def get_hashrate
      hashrate = 0
      @gpu.each do |g|
        hashrate += g.hashrate.avg.to_i
      end
      hashrate
    end
    
    def get_power_usage
      power_draw = 0
      @gpu.each do |g|
        power_draw += g.power_draw.avg.to_i
      end
      power_draw
    end
  
end
