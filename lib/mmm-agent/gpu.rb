class MmmAgent::Gpu
  
  attr_accessor :uuid, :id, :model, :hashrate, :mining_operation
  
  def initialize( id )
    @id = id
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

  def register_if_needed(rig_data, server)
    rig_data['rig']['hardware'].each do |hardware|
      return if hardware['hardware_type'] == 'gpu' and
                hardware['manufacturer']  == @manufacturer and
                hardware['model']         == @model and
                hardware['uuid']          == @uuid and
                hardware['slot']          == @id
      if hardware['hardware_type'] == 'gpu' and hardware['slot'] == @id
        server.patch(hardware['remove_hardware']['url'], nil)
      end
    end

    Log.notice("GPU##{@id} (#{@model}) is missing, registering it on mmm-server")
    new_hardware = {
      :hardware_type  => 'gpu',
      :manufacturer   => @manufacturer,
      :model          => @model,
      :uuid           => @uuid,
      :slot           => @id,
    }
    server.patch(rig_data['rig']['add_hardware']['url'], new_hardware)
  end

  def send_statistics(server, url)
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
    server.patch(url, mining_log)
    clear_statistics
  end
  
end
