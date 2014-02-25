# require 'singleton'
require 'logger'

class MageLogger < Logger
  include Singleton

  LOG_FILE = File.open("server.log", "a") #STDOUT#

  def initialize
    super LOG_FILE

    @default_formatter.datetime_format = "%Y-%m-%d %H:%M:%S"
  end
end
