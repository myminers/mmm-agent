class MmmAgent::MinerParser

  def self.parse(line, gpu)
    case line
    when /GPU #\d.+, ([\d\.]+) ([A-Za-z]?[Hh])\/s/
      # [2016-02-13 21:54:11] GPU #1: GeForce GTX 970, 12696 (T= 57C F= 56% C=1404/3004)
      value = $1
      unit  = $2
      rate = value.to_f * MmmAgent::MinerParser::multiplier(unit.downcase) # Convert to hash/s
      gpu.hashrate = rate.to_i
    when /GPU\d: (\d+) /
      # GPU0: 410 Sol
      gpu.hashrate = $1.to_i
    else
      Log.info "GPU##{gpu.id} Miner output: #{line}"
    end
  end

  def self.multiplier(letter)
    units = [nil, 'kh', 'mh', 'gh', 'th', 'ph', 'eh', 'zh', 'yh']
    orders = Hash[units.map.with_index.to_a]
    units.include?(letter) ? 1000 ** orders[letter] : 1
  end


end
