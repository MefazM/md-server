require 'timers'
require 'network/networking'
require 'player/units_production'
require 'player/response'
require 'player/coins_storage'
require 'player/coins_mine'

module Player
  class PlayerActor
    include Celluloid
    include Celluloid::IO
    include ::Networking::Actions
    include Celluloid::Logger

    include Response
    include CoinsMine
    include CoinsStorage
    include UnitsProduction

    UPDATE_PERIOD = 1
    SERIALIZATION_PERIOD = 20#180

    def initialize ( id, email, username, socket )
      @socket = socket
      @status = :run
      @id = id
      @email = email
      @username = username

      @latency = 0

      @redis_player_key = "players:#{@id}"
      @redis_resources_key = "#{@redis_player_key}:resources"

      units_json = nil
      buildings_json = nil
      units_queue = nil

      Storage::Redis::Pool.connections_pool.with do |redis|
        units_json = redis.connection.hget(@redis_player_key, 'units')
        buildings_json = redis.connection.hget(@redis_player_key, 'buildings')
        units_queue = redis.connection.hget(@redis_player_key, 'units_queue')

        @last_harvest_time = redis.connection.hget(@redis_resources_key, 'last_harvest_time').to_i
        @coins_in_storage = redis.connection.hget(@redis_resources_key, 'coins').to_i
        @harvester_storage = redis.connection.hget(@redis_resources_key, 'harvester_storage').to_i
      end

      @units = units_json.nil? ? {} : JSON.parse(units_json, {:symbolize_names => true})
      @buildings = buildings_json.nil? ? {} : JSON.parse(buildings_json, {:symbolize_names => true})
      @units_production_queue = units_queue.nil? ? {} : JSON.parse(units_queue, {:symbolize_names => true})

      # Buildings uids, assigned to coins generation
      @storage_building_uid = Storage::GameData.storage_building_uid
      @coin_generator_uid = Storage::GameData.coin_generator_uid

      compute_coins_gain
      compute_storage_capacity
      # Frezen player can't be invited to battle
      @frozen = false

      # Send game data to client
      send_game_data

      @timers = Timers.new
      @gold_mine_notification_timer = nil
      reset_gold_mine_full_notification
    end

    def buiding_exist(uid, level)
      @buildings[uid].nil? ? false : @buildings[uid] == level
    end

    def run
      every UPDATE_PERIOD do

        current_time = Time.now.to_f

        @timers.fire

        process_unit_queue current_time
      end

      every SERIALIZATION_PERIOD do
        serialize_player
      end

      listen_socket
    end

    private

    def listen_socket
      Networking::Request.listen_socket(@socket) do |action, data|
        case action
        when RECEIVE_UNIT_PRODUCTION_TASK_ACTION
          unit_uid = data[0].to_sym
          unit = Storage::GameData.unit unit_uid

          building_uid = unit[:depends_on_building_uid]
          building_level = unit[:depends_on_building_level]
          price = unit[:price]

          if buiding_exist(building_uid, building_level)

            if make_payment price
              production_time = unit[:production_time]
              add_unit_production_task(unit_uid, production_time, building_uid)

              send_new_unit_queue_item(unit_uid, building_uid, production_time)
              send_coins_storage_capacity
            end
          end

        when RECEIVE_BUILDING_PRODUCTION_TASK_ACTION

        when RECEIVE_REQUEST_CURRENT_MINE_AMOUNT

          send_current_mine_amount

        when RECEIVE_DO_HARVESTING_ACTION

          unless storage_full?
            harvest
            send_coins_storage_capacity
          end

        when RECEIVE_PING_ACTION

          @latency = (Time.now.to_f - data[0]).round(3)

        end

        @status == :term
      end
    end

    def serialize_player
      Storage::Redis::Pool.connections_pool.with do |redis|
        # serialize units, buildings, coins, queue
        redis.connection.hset(@redis_player_key, 'units', JSON.generate(@units))
        redis.connection.hset(@redis_player_key, 'buildings', JSON.generate(@buildings))
        redis.connection.hset(@redis_player_key, 'units_queue', JSON.generate(@units_production_queue))

        redis.connection.hset(@redis_resources_key, 'last_harvest_time', @last_harvest_time)
        redis.connection.hset(@redis_resources_key, 'coins', @coins_in_storage)
        redis.connection.hset(@redis_resources_key, 'harvester_storage', @harvester_storage)
      end
    end

  end
end