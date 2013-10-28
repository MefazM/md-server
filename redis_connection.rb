require "redis"
require 'singleton'

class RedisConnection
  include Singleton

  def initialize
    @redis = Redis.new
  end

  def connection
    @redis
  end

end
