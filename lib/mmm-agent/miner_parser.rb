class MmmAgent::MinerParser

  def self.parse(line, gpu)
    case line
    when /GPU #\d.+, ([\d\.]+) ([A-Za-z])[Hh]\/s/
      # [2016-02-13 21:54:11] GPU #1: GeForce GTX 970, 12696 (T= 57C F= 56% C=1404/3004)
      value = $1
      unit  = $2
      gpu.hashrate = value.to_i * MmmAgent::MinerParser::multiplier(unit.downcase) # Convert to hash/s
    when /GPU\d: (\d+) /
      # GPU0: 410 Sol
      gpu.hashrate = $1.to_i
    else
      Log.info "GPU##{gpu.id} Miner output: #{line}"
    end
  end

  def self.multiplier(letter)
    units = [nil, 'k', 'm', 'g', 't', 'p', 'e', 'z', 'y']
    orders = Hash[units.map.with_index.to_a]
    units.include?(letter) ? 1000 ** orders[letter] : 1
  end


end
