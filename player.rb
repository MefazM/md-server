
require "securerandom"
require 'pry'

require_relative 'redis_connection.rb'

class Player

  def initialize(id, email, username)
    @id = id
    @email = email
    @username = username

    @redis_player_key = "players:#{@id}"
    @redis_units_key = "#{@redis_player_key}:units"

    @units = {}

    units_json = RedisConnection.instance.connection.hget(@redis_player_key, 'units')

    @units = units_json.nil? ? {} : JSON.parse(units_json)
  end

  def get_game_data()
    return {:buildings => {}, :technologies => {}, :units => {}}
  end

  def get_id()
    return @id
  end

  def to_hash()
    {:id => @id, :username => @username}
  end

  def get_default_unit_package()
    'crusader'
  end

  def get_units_data_for_battle()
    DBResources.get_units(['stone_golem', 'mage', 'doghead', 'elf'])
  end

  def get_main_building()

  end

  def add_unit(unit_id, count = 1)
    units_count = @units[unit_id] || 0

    @units[unit_id] = units_count + count
    serialize_units_to_redis()
    # binding.pry
  end

  def units()
    # RedisConnection.instance.connection.
    # @redis_units_key
  end

private

  def serialize_units_to_redis()

    units_json = @units.to_json

    RedisConnection.instance.connection.hset(@redis_player_key, 'units', units_json)
  end

end
