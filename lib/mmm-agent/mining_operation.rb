require 'pty'

class MmmAgent::MiningOperation

  def initialize(log)
    @log = log
    @raw_data = Hash.new
    @pid = nil
  end

  def update( raw_data )
    if @raw_data == raw_data # No change
      @log.info 'No change in mining command'
    elsif is_valid(raw_data)
      @raw_data = raw_data
      @log.info "Switching to '#{readable_command}'"
      if !@pid.nil?
        begin
          @log.info "Stopping the previous miner..."
          Process.kill('INT', @pid)
          Process.wait(@pid)
        rescue PTY::ChildExited
          # Just wait for the process to stop
        end
      end
    else
      @log.error "Received invalid command, #{raw_data.to_s}"
      @log.info "Staying on: '#{readable_command}'"
    end
  end
  
  def readable_command
    "#{miner} #{algo} #{stratum} #{username} #{password}"
  end
    
  def run_miner
    #Infinite loop: if the miner stops, we restart it
    @log.info 'plop'
    while true
      begin
        @log.info "Starting the miner..."
        PTY.spawn( miner, algo, stratum, username, password, '--no-color' ) do |stdout, stdin, pid|
          begin
            @pid = pid
            @log.info "Miner running with PID #{@pid}"
            stdout.each { |line| @log.info line }
          rescue Errno::EIO
            # If the miner stops without closing stdout properly, we get this error.
            # We don't care about it, we just want to start another process...
            @log.info "Miner stopped output"
          rescue Interrupt
            # We received an interrupt (ctrl-C or kill)
            # Stop the miner properly and exit
            @log.info "Stopping the miner"
            begin
              Process.kill('INT', @pid)
              Process.wait(@pid)
            rescue PTY::ChildExited
              # Just wait for the process to stop
            end
            @log.info "Miner stopped safely, stopping mmm-agent"
            return
          end
        end
      rescue PTY::ChildExited
        @log.info "Miner process exited"
      end
    end
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
    @raw_data['miner']
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
