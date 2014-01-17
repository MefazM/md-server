
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

    # CoinZZ
    @last_harvest_time = RedisConnection.instance.connection.hget("#{@redis_player_key}:resources", 'last_harvest_time')
    raise 'last_harvest_time in nil. Broken player.' if @last_harvest_time.nil?

    # Buildings uids, assigned to coins generation
    @storage_building_uid = GameData.instance.storage_building_uid
    @coin_generator_uid = GameData.instance.coin_generator_uid

    compute_coins_gain()
    compute_storage_capacity()
    # coin_generator_level = building_level(@coin_generator_uid)
    # storage_building_level = building_level(@storage_building_uid)

    # @coins_gain = GameData.instance.production_amount(coin_generator_level)
    # @storage_capacity =  GameData.instance.storage_capacity(storage_building_level)

    @amount_in_storage = RedisConnection.instance.connection.hget("#{@redis_player_key}:resources", 'coins')
    @amount_in_storage = @amount_in_storage.to_i

    if @amount_in_storage.nil?
      MageLogger.instance.info "Coins count is nil. id = #{id}"
      @amount_in_storage = 0
    end
  end

  def harvest
    curent_time = Time.now.to_i
    d_time = curent_time - @last_harvest_time.to_i
    earned = (d_time * @coins_gain).to_i

    @last_harvest_time = curent_time
    RedisConnection.instance.connection.hset("players:#{@id}:resources", "last_harvest_time", curent_time)

    if earned > @harvest_capacity
      earned = @harvest_capacity
    end

    @amount_in_storage += earned

    if @amount_in_storage >= @storage_capacity
      @amount_in_storage = @storage_capacity
    end

    RedisConnection.instance.connection.hset("#{@redis_player_key}:resources", 'coins', @amount_in_storage)

    @amount_in_storage
  end

  def storage_capacity
    @storage_capacity
  end

  def amount_in_storage
    @amount_in_storage
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
      :amount_in_storage => @amount_in_storage,
      :storage_capacity => @storage_capacity,
      :buildings => buildings,
      :units => {
        :queue => units_queue
    }}
  end

  def id
    @id
  end

  def to_i
    [@id, @username]
  end

  def building_level(uid)
    level = @buildings[uid.to_sym] || 0
    level
  end

  def default_unit_uid
    'crusader'
  end

  def units_data_for_battle
    @units.keys
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
    data = GameData.instance.coin_amount(level)
    @coins_gain = data[:amount]
    @harvest_capacity = data[:harvest_capacity]
  end

  # Update storage space if storage building updated
  def compute_storage_capacity
    # binding.pry
    level = building_level(@storage_building_uid)
    @storage_capacity =  GameData.instance.storage_capacity(level)
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
