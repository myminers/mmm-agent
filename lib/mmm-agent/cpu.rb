class MmmAgent::Cpu

  attr_accessor :model, :cores
  
  def initialize
    @model = `grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2`.strip
    @cores = `grep 'cpu cores' /proc/cpuinfo | head -1 | cut -d: -f2`.strip.to_i
    @siblings = `grep 'siblings' /proc/cpuinfo | head -1 | cut -d: -f2`.strip.to_i
  end

  def human_readable
    "#{cores} * #{model} (HyperThreading: #{has_hyperthreading?})"
  end

  def has_hyperthreading?
    @cpu_siblings != @cpu_cores
  end
  
end
