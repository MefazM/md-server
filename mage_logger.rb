require 'singleton'
 
class MageLogger < Logger
  include Singleton

  LOG_FILE = STDOUT#File.open("server.log", "a")

  def initialize
    super LOG_FILE

    @default_formatter.datetime_format = "%Y-%m-%d %H:%M:%S"
  end
end
