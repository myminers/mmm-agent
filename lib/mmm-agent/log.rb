require 'syslog/logger'

class Log
  class << self; attr_accessor :level end
  @logger = Syslog::Logger.new 'mmm-agent'
  @level  = 'debug'
  @LEVELS = {
    'debug'   => 1,
    'info'    => 2,
    'notice'  => 3,
    'warning' => 4,
    'err'     => 5
  }

  # Map syslog's levels to the logger's ones
  def self.debug(msg)
    @logger.debug msg unless @LEVELS[@level] > @LEVELS[__method__.to_s]
  end
  def self.info(msg)
    @logger.info msg unless @LEVELS[@level] > @LEVELS[__method__.to_s]
  end
  def self.notice(msg)
    @logger.warn msg unless @LEVELS[@level] > @LEVELS[__method__.to_s]
  end
  def self.warning(msg)
    @logger.error msg unless @LEVELS[@level] > @LEVELS[__method__.to_s]
  end
  def self.err(msg)
    @logger.fatal msg unless @LEVELS[@level] > @LEVELS[__method__.to_s]
  end
  
end
