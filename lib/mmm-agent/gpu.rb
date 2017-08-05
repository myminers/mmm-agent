class MmmAgent::Gpu
  
  attr_accessor :uuid, :id, :model, :gpu_clock, :mem_clock, :gpu_usage, :mem_usage, :fan_speed, :temperature, :power_draw, :hashrate, :mining_operation
  
  def initialize( id )
    @id = id
    data = get_smi_data.split(', ')
    @manufacturer = 'nvidia'
    @uuid = data[0].strip
    @model = data[1].strip
    
    # Create MiningOperation object
    @mining_operation = MmmAgent::MiningOperation.new(self)
    
    # Create stats objects
    @gpu_clock = Stat.new
    @mem_clock = Stat.new
    @gpu_usage = Stat.new
    @mem_usage = Stat.new
    @fan_speed = Stat.new
    @temperature = Stat.new
    @power_draw = Stat.new
    @hashrate = Stat.new
  end
  
  def get_smi_data
    `nvidia-smi --query-gpu=uuid,name,clocks.gr,clocks.mem,utilization.gpu,utilization.memory,fan.speed,temperature.gpu,power.draw,clocks_throttle_reasons.hw_slowdown --format=csv,noheader,nounits -i #{@id}`
  end
  
  def update_stats
    data = get_smi_data.split(', ')
    @gpu_clock.push( data[2].strip.to_i )
    @mem_clock.push( data[3].strip.to_i )
    @gpu_usage.push( data[4].strip.to_i )
    @mem_usage.push( data[5].strip.to_i )
    @fan_speed.push( data[6].strip.to_i )
    @temperature.push( data[7].strip.to_i )
    @power_draw.push( data[8].strip.to_i )  
  end
  
  def store_hashrate( rate )
    @hashrate.push( rate )
  end
  
  def clear_statistics
    @gpu_clock.clear
    @mem_clock.clear
    @gpu_usage.clear
    @mem_usage.clear
    @fan_speed.clear
    @temperature.clear
    @power_draw.clear
    @hashrate.clear
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
  
end
