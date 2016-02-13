class MmmAgent::Gpu
  
  attr_accessor :uuid, :id, :model, :gpu_clock, :mem_clock, :gpu_usage, :mem_usage, :fan_speed, :temperature, :power_draw, :hashrate
  
  def initialize( id, log )
    @id = id
    @log = log
    data = get_smi_data.split(', ')
    @uuid = data[0].strip
    @model = data[1].strip
    
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
  
end
