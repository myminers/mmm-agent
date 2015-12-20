require 'optparse'
require 'optparse/time'
require 'ostruct'
require 'pp'
require 'socket'
    
class Optparse

  CODES = %w[iso-2022-jp shift_jis euc-jp utf8 binary]
  CODE_ALIASES = { "jis" => "iso-2022-jp", "sjis" => "shift_jis" }

  #
  # Return a structure describing the options.
  #
  def self.parse(args)
    # The options specified on the command line will be collected in *options*.
    # We set default values here.
    options = OpenStruct.new
    options.server_url = "https://www.multiminermanager.com"
    options.hostname = Socket.gethostname

    opt_parser = OptionParser.new do |opts|
      opts.banner = "Usage: mmm-agent -e EMAIL -t TOKEN [options]"

      opts.separator ""
      opts.separator "Required parameters:"

      # Mandatory arguments.
      opts.on("-e", "--email EMAIL",
              "User account on mmm-server") do |email|
        options.email = email
      end

      opts.on("-t", "--token TOKEN",
              "API token on mmm-server") do |token|
        options.token = token
      end
      
      opts.separator ""
      opts.separator "Options:"

      opts.on("-s", "--server SERVER",
              "Defaults to https://www.multiminermanager.com") do |server|
        options.server_url = server
      end

      # No argument, shows at tail.  This will print an options summary.
      # Try it and see!
      opts.on_tail("-h", "--help", "Show this message") do
        puts opts
        exit
      end

      # Another typical switch to print the version.
      opts.on_tail("-v", "--version", "Show version") do
        puts MmmAgent.version
        exit
      end
    end

    opt_parser.parse!(args)
    
    if options.email.nil? or options.token.nil?
      puts "Missing arguments. Run again with --help"
      exit 1
    end
    
    options
  end

end
