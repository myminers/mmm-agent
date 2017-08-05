require 'pty'

class MmmAgent::MiningOperation

  def initialize(device)
    @raw_data = Hash.new
    @device = device
    @pid = nil
  end

  def update( raw_data )
    if @raw_data == raw_data # No change
      Log.info 'No change in mining command'
    elsif is_valid(raw_data)
      @raw_data = raw_data
      Log.notice "Switching to '#{readable_command}'"
      if !@pid.nil?
        begin
          Log.info "Stopping the previous miner..."
          Process.kill('INT', @pid)
          Process.wait(@pid)
        rescue PTY::ChildExited
          # Just wait for the process to stop
        end
        @host.clear_statistics # Ignore the last stats output, as we are probably changing algorithm
      end
    else
      Log.warning "Received invalid command, #{raw_data.to_s}"
      Log.warning "Staying on: '#{readable_command}'"
    end
  end
  
  def readable_command
    m = @raw_data['what_to_mine']
    mining_command = m['command'].dup
    mining_command.sub! 'MINER',        m['miner']
    mining_command.sub! 'DEVICE',       m['device']
    mining_command.sub! 'ALGO',         m['algo']
    mining_command.sub! 'STRATUM_HOST', stratum_host( m['stratum'] )
    mining_command.sub! 'STRATUM_PORT', stratum_port( m['stratum'] )
    mining_command.sub! 'STRATUM',      m['stratum']
    mining_command.sub! 'USERNAME',     m['username']
    mining_command.sub! 'PASSWORD',     m['password']
    return mining_command
  end
    
  def run_miner
    #Infinite loop: if the miner stops, we restart it
    while true
      begin
        Log.notice "Starting the miner..."
        PTY.spawn( miner, algo, stratum, username, password, '--no-color' ) do |stdout, stdin, pid|
          begin
            @pid = pid
            Log.debug "Miner running with PID #{@pid}"
            stdout.each { |line| MmmAgent::CcminerParser::parse(line, @host) }
          rescue Errno::EIO
            # If the miner stops without closing stdout properly, we get this error.
            # We don't care about it, we just want to start another process...
            Log.debug "Miner stopped output"
          rescue Interrupt
            # We received an interrupt (ctrl-C or kill)
            # Stop the miner properly and exit
            Log.info "Stopping the miner"
            begin
              Process.kill('INT', @pid)
              Process.wait(@pid)
            rescue PTY::ChildExited
              # Just wait for the process to stop
            end
            Log.info "Miner stopped safely, stopping mmm-agent"
            return
          end
        end
      rescue PTY::ChildExited
        Log.debug "Miner process exited"
      end
    end
  end 
  
  def algo_name
    @raw_data['algo'].capitalize
  end
 
  private
  
  def is_valid( raw_data )
    m = raw_data['what_to_mine']
    if m['miner'] !~ /\A[a-z0-9\-\.]+\z/
      Log.warning("Invalid miner name: #{m['miner']}")
      return false
    end
    if !system("which #{m['miner']} > /dev/null 2>&1")
      Log.warning("Miner missing: #{m['miner']}")
      return false
    end
    if m['device'] !~ /\A[0-9]+\z/
      Log.warning("Invalid device number: #{m['device']}")
      return false
    end
    if m['algo'] !~ /\A[a-z0-9\-\/]+\z/
      Log.warning("Invalid algo: #{m['algo']}")
      return false
    end
    if m['stratum'] !~ /\A[a-z0-9\-\:\.]+\z/
       Log.warning("Invalid stratum: #{m['stratum']}")
       return false
    end
    if m['username'] !~ /\A[a-zA-Z0-9\-\.]+\z/
       Log.warning("Invalid username: #{m['username']}")
       return false
    end
    if m['password'] !~ /\A[a-zA-Z0-9\-\.=]+\z/
       Log.warning("Invalid password: #{m['password']}")
       return false
    end
    if m['command'] !~ /\A[a-zA-Z0-9\-\.=_ ]+\z/
      Log.warning("Invalid command: #{m['command']}")
      return false
    end
    return true
  end
  
  def miner
    case @raw_data['algo']
    when "neoscrypt"
      "ccminer-djm"
    else
      "ccminer-sp"
    end
  end
  
  def algo
    "--algo=#{@raw_data['algo']}"
  end
  
  def stratum
    "--url=stratum+tcp://#{@raw_data['stratum']}"
  end
  
  def username
    "--user=#{@raw_data['username']}"
  end
  
  def password
    "--pass=#{@raw_data['password']}"
  end

  def stratum_host( stratum )
    stratum.split(':')[0]
  end

  def stratum_port( stratum )
    stratum.split(':')[1]
  end
  
end
