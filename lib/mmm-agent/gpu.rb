class MmmAgent::Gpu
  
  attr_accessor :uuid, :id, :model, :hashrate, :mining_operation, :url
  
  def initialize( id, server, options )
    @id = id
    @server = server
    @options = options
    @url = nil
    data = get_smi_data.split(', ')
    @manufacturer = 'nvidia'
    @uuid = data[0].strip
    @model = data[1].strip
    
    # Create MiningOperation object
    @mining_operation = MmmAgent::MiningOperation.new(self)
    
    # Create stats objects
    @gpu_clock        = nil
    @mem_clock        = nil
    @gpu_usage        = nil
    @mem_usage        = nil
    @fan_speed        = nil
    @temperature      = nil
    @power_usage      = nil
    @hashrate         = nil
    @throttle_reason  = nil
  end

  def start_miner
    # Get the first mining operation we will be working on
    @mining_operation.update( get_what_to_mine )

    # Start the miner
    @mining_operation.run_miner
  end

  def monitor_miner
    # Monitor the miner and keep in sync with mmm-server
    while true
			begin
        sleep 60
				# Send statistics every minute, no matter what
				send_statistics

				# If the mining_operation has run for the recommended duration, check if there is a better one
				@mining_operation.running_time += 1
				if @mining_operation.running_time >= @mining_operation.duration
					@mining_operation.running_time = 0
					@mining_operation.update( get_what_to_mine )
				end
      rescue StandardError => e
        Log.warning "Exception: #{e.to_s}"
        Log.warning e.backtrace.map {|line| "  #{line}"}
      end
    end
  end

  def set_url(rig_data)
    rig_data['rig']['hardware'].each do |hardware|
      @url = hardware['url'] if hardware['slot'] == @id
    end
  end

  def get_what_to_mine
    while true
      data = @server.get(@url)
      if data['rig_hardware'].nil?
        Log.warning "No mining operation for GPU##{@id}. Go configure your rig on #{@options.server_url}"
        sleep 60
      else
        return data['rig_hardware']
      end
    end
  end
  
  def get_smi_data
    `nvidia-smi --query-gpu=uuid,name,clocks.gr,clocks.mem,utilization.gpu,utilization.memory,fan.speed,temperature.gpu,power.draw,clocks_throttle_reasons.hw_slowdown --format=csv,noheader,nounits -i #{@id}`
  end
  
  def update_stats
    data = get_smi_data.split(', ')
    @gpu_clock        = data[2].strip.to_i
    @mem_clock        = data[3].strip.to_i
    @gpu_usage        = data[4].strip.to_i
    @mem_usage        = data[5].strip.to_i
    @fan_speed        = data[6].strip.to_i
    @temperature      = data[7].strip.to_i
    @power_usage      = data[8].strip.to_i  
    @throttle_reason  = data[9].strip
  end
  
  def clear_statistics
    @gpu_clock        = nil
    @mem_clock        = nil
    @gpu_usage        = nil
    @mem_usage        = nil
    @fan_speed        = nil
    @temperature      = nil
    @power_usage      = nil
    @hashrate         = nil
    @throttle_reason  = nil
  end

  def register_if_needed(rig_data)
    rig_data['rig']['hardware'].each do |hardware|
      # Stop here if the server knows about me
      return if hardware['hardware_type'] == 'gpu' and
                hardware['manufacturer']  == @manufacturer and
                hardware['model']         == @model and
                hardware['uuid']          == @uuid and
                hardware['slot']          == @id

      # If a different GPU is declared on my slot, remove it
      if hardware['hardware_type'] == 'gpu' and hardware['slot'] == @id
        @server.patch(hardware['remove_hardware']['url'], nil)
      end
    end

    # Register myself if the server doesn't know about me
    Log.notice("GPU##{@id} (#{@model}) is missing, registering it on mmm-server")
    new_hardware = {
      :hardware_type  => 'gpu',
      :manufacturer   => @manufacturer,
      :model          => @model,
      :uuid           => @uuid,
      :slot           => @id,
    }
    @server.patch(rig_data['rig']['add_hardware']['url'], new_hardware)
  end

  def send_statistics
    update_stats
    Log.info "Sending stats to mmm-server: rate:#{@hashrate} power:#{@power_usage} temp: #{@temperature} fan:#{@fan_speed} gpu:#{@gpu_usage} mem:#{@mem_usage} throttle:#{@throttle_reason}"
    mining_log = {
      :rate             => @hashrate,
      :power_usage      => @power_usage,
      :temperature      => @temperature,
      :fan_speed        => @fan_speed,
      :gpu_usage        => @gpu_usage,
      :mem_usage        => @mem_usage,
      :throttle_reason  => @throttle_reason
    }
    @server.patch(@mining_operation.log_url, mining_log)
    clear_statistics
  end
  
end
