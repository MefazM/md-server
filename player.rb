
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

    units_json = RedisConnection.instance.connection.hget(@redis_player_key, 'units')
    @units = units_json.nil? ? {} : JSON.parse(units_json, {:symbolize_names => true})

    buildings_json = RedisConnection.instance.connection.hget(@redis_player_key, 'buildings')
    @buildings = buildings_json.nil? ? {} : JSON.parse(buildings_json, {:symbolize_names => true})

    #Resources
    prod_building_level = 1

    @amount = 200 #per second
    @last_harvest = RedisConnection.instance.connection.hget(@redis_player_key, 'last_harvest_time')
    raise 'last_harvest_time in nil. Broken player.' if @last_harvest.nil?

  end

  def harvest
    curent_time = Time.now.to_i
    d_time = curent_time - @last_harvest.to_i
    earned = d_time * @amount

    @last_harvest = curent_time
    RedisConnection.instance.connection.hset("players:#{@id}:resources", "last_harvest_time", curent_time)

    earned
  end

  def get_game_data
    buildings = {}

    @buildings.each do |uid, level|
      buildings[uid] = {:level => level, :ready => true, :uid => uid}
    end

    buildings_queue = BuildingsFactory.instance.buildings_in_queue(@id)

    buildings_queue.each do |uid, data|
      buildings[uid] = data
      # mark as not ready building in queue
      buildings[uid][:ready] = false
    end

    units_queue = UnitsFactory.instance.units_in_queue(@id)

    return {
      :buildings => buildings,
      :units => {
        :queue => units_queue
    }}
  end

  def get_id
    @id
  end

  def to_i
    [@id, @username]
  end

  def get_building_level(uid)
    level = @buildings[uid.to_sym] || 0
    level
  end

  def get_default_unit_uid
    'crusader'
  end

  def get_units_data_for_battle
    @units.keys
  end

  def get_main_building

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


  def self.create(login_data)
    DBConnection.query(
      "INSERT INTO players (email, username)
      VALUES ('#{login_data[:email]}', '#{login_data[:name]}')"
    )

    player_id = DBConnection.last_inser_id

    DBConnection.query(
      "INSERT INTO authentications (player_id, provider, token)
      VALUES (#{player_id}, '#{login_data[:provider]}', '#{login_data[:token]}')"
    )

    MageLogger.instance.info "New player created. id = #{player_id}"

    RedisConnection.instance.connection.hset("players:#{player_id}", "last_harvest_time", Time.now.to_i)

    return player_id
  end

private

  def serialize_units_to_redis
    units_json = @units.to_json
    RedisConnection.instance.connection.hset(@redis_player_key, 'units', units_json)
  end

  def serialize_buildings_to_redis
    buildings_json = @buildings.to_json
    RedisConnection.instance.connection.hset(@redis_player_key, 'buildings', buildings_json)
  end

end
