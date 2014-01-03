require 'singleton'
require 'logger'

class MageLogger < Logger
  include singleton

  LOG_FILE = STDOUT#File.open("server.log", "a")

  def initialize
    super LOG_FILE

    @default_formatter.datetime_format = "%Y-%m-%d %H:%M:%S"
  end
end
