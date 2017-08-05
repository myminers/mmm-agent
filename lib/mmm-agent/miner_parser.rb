class MmmAgent::MinerParser

  def self.parse(line, gpu)
    case
    when /GPU #\d.+, (?<hash>\d+)/ =~ line
      # [2016-02-13 21:54:11] GPU #1: GeForce GTX 970, 12696 (T= 57C F= 56% C=1404/3004)
      rate = hash.to_i * 1000 # Convert to hash/s
      gpu.update_stats # Get T°, power and resource usage from nvidia_smi
      gpu.store_hashrate(rate)
    when /GPU\d: (?<rate>\d+) Sol/
      # GPU0: 410 Sol
      gpu.update_stats
      gpu.store_hashrate(rate)
    else
      Log.warn "Miner output: #{line}"
    end
  end

end
