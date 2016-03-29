class MmmAgent::CcminerParser

  def self.parse(line, host)
    case
    when /GPU #(?<gpuid>\d).+, (?<hash>\d+)/ =~ line
      # [2016-02-13 21:54:11] GPU #1: GeForce GTX 970, 12696 (T= 57C F= 56% C=1404/3004)
      id = gpuid.to_i
      rate = hash.to_i * 1000 # Convert to hash/s
      host.gpu[id].update_stats # Get T°, power and resource usage from nvidia_smi
      host.gpu[id].store_hashrate(rate)
    else
      clean_line = line.sub(/\A\[.+\]/, '')
      Log.info "Miner output: #{clean_line}"
    end
  end

end
