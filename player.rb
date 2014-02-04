
require "securerandom"
require 'pry'
require_relative 'redis_connection.rb'
class Player

  attr_accessor :id, :storage_capacity, :coins_in_storage, :harvester_capacity, :coins_gain, :units, :username

  def initialize(id, email, username)
    @id = id
    @email = email
    @username = username

    @redis_player_key = "players:#{@id}"
    @redis_units_key = "#{@redis_player_key}:units"
    @redis_resources_key = "#{@redis_player_key}:resources"

    units_json = RedisConnection.instance.connection.hget(@redis_player_key, 'units')
    @units = units_json.nil? ? {} : JSON.parse(units_json, {:symbolize_names => true})

    buildings_json = RedisConnection.instance.connection.hget(@redis_player_key, 'buildings')
    @buildings = buildings_json.nil? ? {} : JSON.parse(buildings_json, {:symbolize_names => true})
    # CoinZZ
    @last_harvest_time = redis_get(@redis_resources_key, 'last_harvest_time', Time.now.to_i)
    # Buildings uids, assigned to coins generation
    @storage_building_uid = GameData.instance.storage_building_uid
    @coin_generator_uid = GameData.instance.coin_generator_uid

    compute_coins_gain()
    compute_storage_capacity()

    @coins_in_storage = redis_get(@redis_resources_key, 'coins', 0).to_i
    @harvester_storage = redis_get(@redis_resources_key, 'harvester_storage', 0).to_i

    @frozen = false
  end

  def freeze!
    @frozen = true
  end

  def unfreeze!
    @frozen = false
  end

  def frozen?
    @frozen
  end

  def idle?
    @state == PLAYER_STATE_IDLE
  end

  def harvest
    current_time = Time.now.to_i
    d_time = current_time - @last_harvest_time.to_i
    earned = (d_time * @coins_gain).to_i

    @harvester_storage += earned

    if @harvester_storage > @harvester_capacity
      @harvester_storage = @harvester_capacity
    end

    @coins_in_storage += @harvester_storage

    if @coins_in_storage >= @storage_capacity
      @harvester_storage = @coins_in_storage - @storage_capacity
      @coins_in_storage = @storage_capacity
    else
      @harvester_storage = 0
    end

    @last_harvest_time = current_time

    redis_set(@redis_resources_key, "last_harvest_time", current_time)
    redis_set(@redis_resources_key, 'coins', @coins_in_storage)
    redis_set(@redis_resources_key, 'harvester_storage', @harvester_storage)
  end

  def storage_full?
    @coins_in_storage >= @storage_capacity
  end

  def mine_amount current_time
    d_time = current_time - @last_harvest_time.to_i
    earned = (d_time * @coins_gain).to_i + @harvester_storage
    earned
  end

  def game_data
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
      :coins_in_storage => @coins_in_storage,
      :storage_capacity => @storage_capacity,
      :buildings => buildings,
      :units => {
        :queue => units_queue
    }}
  end

  def make_payment coins
    enough_coins = @coins_in_storage >= coins
    if enough_coins
      @coins_in_storage -= coins
      redis_set(@redis_resources_key, 'coins', @coins_in_storage)
    end

    enough_coins
  end


  def building_level(uid)
    level = @buildings[uid.to_sym] || 0
    level
  end

  def default_unit_uid
    'crusader'
  end


  def add_unit(unit_id, count = 1)
    units_count = @units[unit_id] || 0

    @units[unit_id] = units_count + count
    serialize_units_to_redis()
  end

  def add_or_update_building(uid, level)
    building_uid = uid.to_sym

    @buildings[uid.to_sym] = level
    serialize_buildings_to_redis()
  end

  # Update amount if coin generator building updated
  def compute_coins_gain
    level = building_level(@coin_generator_uid)
    data = GameData.instance.harvester(level)

    @coins_gain = data[:amount]
    @harvester_capacity = data[:harvester_capacity]
  end

  # Update storage space if storage building updated
  def compute_storage_capacity
    level = building_level(@storage_building_uid)
    @storage_capacity =  GameData.instance.storage_capacity(level)
  end

  # Sync player after battle
  # -add earned points
  # -decrease units count
  # -other...
  def sync_after_battle(options)
    options[:units].each do |uid, unit_data|
      @units[uid] -= unit_data[:lost]
      # Destroy field if no units left.
      if @units[uid] <= 0
        @units.delete(uid)
      end
    end
    serialize_units_to_redis()

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

    RedisConnection.instance.connection.hset("players:#{player_id}:resources", "last_harvest_time", Time.now.to_i)
    RedisConnection.instance.connection.hset("players:#{player_id}:resources", 'coins', 0)
    RedisConnection.instance.connection.hset("players:#{player_id}:resources", 'harvester_storage', 0)

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

  def redis_get key, field, default = 0
    value = RedisConnection.instance.connection.hget(key, field)
    value = default if value.nil?
    value
  end

  def redis_set key, field, value
    RedisConnection.instance.connection.hset(key, field, value)
  end

end
