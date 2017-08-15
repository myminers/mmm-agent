require 'pty'

class MmmAgent::MiningOperation

  attr_accessor :log_url, :running_time, :duration

  def initialize(device)
    @raw_data = Hash.new
    @device = device
    @pid = nil
    @log_url = nil
    @running_time = 0
    @duration = 0
  end

  def update( raw_data )
    if @raw_data == raw_data # No change
      Log.info "GPU##{@device.id} No change in mining command, keep mining for #{@duration} more minutes"
    elsif is_valid(raw_data)
      @raw_data = raw_data
      @log_url = raw_data['mining_log']['url']
      @duration = raw_data['what_to_mine']['duration'].to_i
      Log.notice "GPU##{@device.id} Switching to '#{readable_command(@raw_data['what_to_mine'])}' for #{@duration} minutes"
      if !@pid.nil?
        begin
          Log.info "GPU##{@device.id} Stopping the previous miner..."
          Process.kill('INT', @pid)
          Process.wait(@pid)
        rescue PTY::ChildExited
          # Just wait for the process to stop
        end
        @device.clear_statistics # Ignore the last stats output, as we are probably changing algorithm
      end
    else
      Log.warning "GPU##{@device.id} Received invalid command, staying on: '#{readable_command}'"
    end
  end
  
  def run_miner
    #Infinite loop: if the miner stops, we restart it
    while true
      begin
        Log.notice "GPU##{@device.id} Starting the miner..."
        PTY.spawn( readable_command(@raw_data['what_to_mine'])) do |stdout, stdin, pid|
          begin
            @pid = pid
            Log.debug "GPU##{@device.id} Miner running with PID #{@pid}"
            stdout.each { |line| MmmAgent::MinerParser::parse(line, @device) }
          rescue Errno::EIO
            # If the miner stops without closing stdout properly, we get this error.
            # We don't care about it, we just want to start another process...
            Log.debug "GPU##{@device.id} Miner stopped output"
          end
        end
      rescue PTY::ChildExited
        Log.debug "GPU##{@device.id} Miner process exited"
      rescue NoMethodError => e
        Log.info "GPU##{@device.id} Nothing to do, waiting..."
        sleep 10
      rescue Exception => e
        # Ruby swallows exceptions that happen in a thread.
        # That way, they are at least displayed...
        puts "Thread terminated with exception: #{e.message}"
        puts e.backtrace.map {|line| "  #{line}"}
        raise e
      end
    end
  end 
  
  private
  
  def is_valid( raw_data )
    # We don't trust the values coming from mmm-server:
    # If the server gets hacked we don't want an attacker to be able to run arbitrary commands on our rig.
    # Validating each parameter to the minimum set of characters mitigates the risk but does not nullify it.
    # You should never, under any circumstance, run this as root.
    m = raw_data['what_to_mine']
    if m['miner'] !~ /\A[a-z0-9\-\.]+\z/
      Log.warning("GPU##{@device.id} Invalid miner name: #{m['miner']}")
      return false
    end
    if !system("which #{m['miner']} > /dev/null 2>&1")
      Log.warning("GPU##{@device.id} Miner missing: #{m['miner']}")
      return false
    end
    if m['device'] !~ /\A[0-9]+\z/
      Log.warning("GPU##{@device.id} Invalid device number: #{m['device']}")
      return false
    end
    if m['algo'] !~ /\A[a-z0-9\-\/]+\z/
      Log.warning("GPU##{@device.id} Invalid algo: #{m['algo']}")
      return false
    end
    if m['stratum'] !~ /\A[a-z0-9\-\:\.]+\z/
       Log.warning("GPU##{@device.id} Invalid stratum: #{m['stratum']}")
       return false
    end
    if m['username'] !~ /\A[a-zA-Z0-9\-\.]+\z/
       Log.warning("GPU##{@device.id} Invalid username: #{m['username']}")
       return false
    end
    if m['password'] !~ /\A[a-zA-Z0-9\-\.=]+\z/
       Log.warning("GPU##{@device.id} Invalid password: #{m['password']}")
       return false
    end
    if m['command'] !~ /\AMINER [a-zA-Z0-9\-\.\/\+\:=_ ]+\z/
      Log.warning("GPU##{@device.id} Invalid command: #{m['command']}")
      return false
    end
    return true
  end

  def stratum_host( stratum )
    stratum.split(':')[0]
  end

  def stratum_port( stratum )
    stratum.split(':')[1]
  end
  
  def readable_command(m)
    mining_command = m['command'].dup
    mining_command.sub! 'MINER',        m['miner']
    mining_command.sub! 'DEVICE',       m['device']
    mining_command.sub! 'ALGO',         m['algo']
    mining_command.sub! 'STRATUM_HOST', stratum_host( m['stratum'] )
    mining_command.sub! 'STRATUM_PORT', stratum_port( m['stratum'] )
    mining_command.sub! 'STRATUM',      m['stratum']
    mining_command.sub! 'USERNAME',     m['username']
    mining_command.sub! 'PASSWORD',     m['password']
#    if m['miner'].match /\Azcash\-miner\-ewbf/
#      api_port = 42000 + m['device'].to_i
#      mining_command += " --api 127.0.0.1:#{api_port}"
#    end
    return mining_command
  end
    
end
