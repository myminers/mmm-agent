require 'pty'

class MmmAgent::MiningOperation

  def initialize(host)
    @raw_data = Hash.new
    @host = host
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
        @host.clear_statistics
      end
    else
      Log.warning "Received invalid command, #{raw_data.to_s}"
      Log.warning "Staying on: '#{readable_command}'"
    end
  end
  
  def readable_command
    "#{miner} #{algo} #{stratum} #{username} #{password}"
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
            stdout.each { |line| MmmAgent::MiningOperation::parse(line, @host) }
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
    return true if raw_data['miner'] == 'ccminer' and
      raw_data['algo'] =~ /\A[a-z0-9\-\/]+\z/ and
      raw_data['stratum'] =~ /\A[a-z0-9\-\:\.]+\z/ and
      raw_data['username'] =~ /\A[a-zA-Z0-9\-\.]+\z/ and
      raw_data['password'] =~ /\A[a-zA-Z0-9\-\.]+\z/
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
  
end
