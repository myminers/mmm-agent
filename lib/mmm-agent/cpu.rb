class MmmAgent::Cpu

  attr_accessor :model, :cores, :manufacturer
  
  def initialize


    @manufacturer = `grep 'vendor_id' /proc/cpuinfo | head -1 | cut -d: -f2`.strip
    @model = `grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2`.strip
    @cores = `grep 'cpu cores' /proc/cpuinfo | head -1 | cut -d: -f2`.strip.to_i
    @siblings = `grep 'siblings' /proc/cpuinfo | head -1 | cut -d: -f2`.strip.to_i
    @manufacturer = 'intel' if @manufacturer == 'GenuineIntel'
  end

  def human_readable
    "#{cores} * #{model} (HyperThreading: #{has_hyperthreading?})"
  end

  def has_hyperthreading?
    @cpu_siblings != @cpu_cores
  end
  
  def register_if_needed(rig_data, server)
    rig_data['rig']['hardware'].each do |hardware|
      return if hardware['hardware_type'] == 'cpu' and
                hardware['manufacturer']  == @manufacturer and
                hardware['model']         == @model and
                hardware['uuid']          == nil and
                hardware['slot']          == 0
      if hardware['hardware_type'] == 'cpu'
        server.patch(hardware['remove_hardware']['url'], nil)
      end
    end

    Log.notice("CPU#0 (#{@model}) is missing, registering it on mmm-server")
    new_hardware = {
      :hardware_type  => 'cpu',
      :manufacturer   => @manufacturer,
      :model          => @model,
      :uuid           => nil,
      :slot           => 0,
    }
    server.patch(rig_data['rig']['add_hardware']['url'], new_hardware)
  end

end
