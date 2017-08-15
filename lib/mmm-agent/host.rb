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

    # Get what mmm-server knows about the Rig
    @rig_data = get_rig_data

    # Make sure mmm-server knows what agent version we are using
    set_version_number

    # Get informations about the GPUs (Nvidia only ATM)
    abort("You don't have any Nvidia GPUs.") if !has_nvidia_gpus?
    @gpu = Array.new
    (0..nvidia_gpus_count - 1).each do |id|
      @gpu[id] = MmmAgent::Gpu.new( id, @server, @options )
      @gpu[id].register_if_needed(@rig_data)
    end

    # Tell mmm-server about the miners we have
    register_miners

    # Reload rig data after everything is registered
    @rig_data = get_rig_data

    # Tell each GPU about its URL on mmm-server
    @gpu.each do |gpu|
      gpu.set_url(@rig_data)
    end
  end

  
  def start_mining
    # Start the miners
    threads = []
    @gpu.each do |gpu|
      threads << Thread.new { gpu.start_mining }
    end

    # Wait for the threads to exit
    threads.each(&:join)
  end

  private

    def get_rig_data
      return @server.get(@rig_url)
    end

    def registered_miners
      miners = Array.new
      @rig_data['rig']['miners'].each do |miner|
        miners << miner['name']
      end
      miners
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

    def update_rig_mining_operations
      @gpu.each do |gpu|
        gpu.update_mining_operation
      end
    end

end
