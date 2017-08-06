class MmmAgent::MinerParser

  def self.parse(line, gpu)
    case line
    when /GPU #\d.+, (\d+) /
      # [2016-02-13 21:54:11] GPU #1: GeForce GTX 970, 12696 (T= 57C F= 56% C=1404/3004)
      gpu.hashrate = $1.to_i * 1000 # Convert to hash/s
    when /GPU\d: (\d+) /
      # GPU0: 410 Sol
      gpu.hashrate = $1.to_i
    else
      Log.info "GPU##{gpu['slot']} Miner output: #{line}"
    end
  end

end
