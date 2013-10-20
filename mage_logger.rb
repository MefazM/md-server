require 'singleton'
 
class MageLogger < Logger
  include Singleton

  LOG_FILE = STDOUT#File.open("server.log", "a")

  def initialize
    super LOG_FILE

    # original_formatter = Formatter.new
    # @formatter = proc { |severity, datetime, progname, msg|
    #   original_formatter.call(severity, datetime, progname, msg.dump)
    # }
    @default_formatter.datetime_format = "%Y-%m-%d %H:%M:%S"
  end
end
