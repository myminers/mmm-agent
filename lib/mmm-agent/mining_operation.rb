class MmmAgent::MiningOperation

  def initialize(log)
    @log = log
    @raw_data = Hash.new
  end

  def update( raw_data )
    @log.info "Got mining operation: #{raw_data.to_s}"
    if @raw_data == raw_data # No change
      @log.info 'No change in mining command'
    elsif is_valid(raw_data)
      @raw_data = raw_data
      @log.info "Switching to '#{readable_command}'"
    else
      @log.error "Received invalid command, staying on: '#{readable_command}'"
    end
  end
  
  def readable_command
    "#{miner} -a #{algo} -o #{stratum} -u #{username} -p #{password}"
  end
  
  private
  
  def is_valid( raw_data )
    return true if raw_data['miner'] == 'ccminer' and
      raw_data['algo'] =~ /\A[a-z0-9\-\/]+\z/ and
      raw_data['stratum'] =~ /\A[a-z0-9\-\:\.]+\z/ and
      raw_data['username'] =~ /\A[a-zA-Z0-9\-]+\z/ and
      raw_data['password'] =~ /\A[a-zA-Z0-9\-]+\z/
  end
  
  def miner
    @raw_data['miner']
  end
  
  def algo
    @raw_data['algo']
  end
  
  def stratum
    "stratum+tcp://#{@raw_data['stratum']}"
  end
  
  def username
    @raw_data['username']
  end
  
  def password
    @raw_data['password']
  end
  
end
