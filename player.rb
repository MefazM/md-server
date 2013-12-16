
require "securerandom"
require 'pry'

require_relative 'deferred_tasks.rb'
require_relative 'redis_connection.rb'


class Player

  def initialize(id, email, username)
    @id = id
    @email = email
    @username = username

    @redis_player_key = "players:#{@id}"
    @redis_units_key = "#{@redis_player_key}:units"

    units_json = RedisConnection.instance.connection.hget(@redis_player_key, 'units')
    @units = units_json.nil? ? {} : JSON.parse(units_json, {:symbolize_names => true})

    buildings_json = RedisConnection.instance.connection.hget(@redis_player_key, 'buildings')
    @buildings = buildings_json.nil? ? {} : JSON.parse(buildings_json, {:symbolize_names => true})

  end

  def get_game_data()
    buildings = {}

    @buildings.each do |package, level|
      buildings[package] = {:level => level, :ready => true, :package => package}
    end

    buildings_in_queue = DeferredTasks.instance.get_buildings_in_queue(@id)

    buildings_in_queue.each do |package, data|
      buildings[package] = data
    end

    units_queue = UnitsFactory.instance.units_in_queue(@id)

    return {
      :buildings => buildings,
      :units => {
        :queue => units_queue
    }}
  end

  def get_id()
    return @id
  end

  def to_hash()
    {:id => @id, :username => @username}
  end

  def to_i
    [@id, @username]
  end

  def get_building_level(package)
    level = @buildings[package.to_sym] || 0
    level
  end

  def get_default_unit_package()
    'crusader'
  end

  def get_units_data_for_battle()
    @units.keys
  end

  def get_main_building()

  end

  def add_unit(unit_id, count = 1)
    units_count = @units[unit_id] || 0

    @units[unit_id] = units_count + count
    serialize_units_to_redis()
  end

  def add_or_update_building(uid, level)
    @buildings[uid.to_sym] = level
    serialize_buildings_to_redis()
  end

private

  def serialize_units_to_redis()
    units_json = @units.to_json
    RedisConnection.instance.connection.hset(@redis_player_key, 'units', units_json)
  end

  def serialize_buildings_to_redis()
    buildings_json = @buildings.to_json
    RedisConnection.instance.connection.hset(@redis_player_key, 'buildings', buildings_json)
  end

end
