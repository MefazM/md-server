require 'timers'
require 'network/networking'
require 'player/units_production'
require 'player/buildings_production'
require 'player/response'
require 'player/request'
require 'player/coins_storage'
require 'player/coins_mine'
require 'player/battle_messages_proxy'


module Player
  class PlayerActor
    include Celluloid

    include ::Networking::Actions
    include Celluloid::Logger
    include Celluloid::Notifications

    include Response
    include RequestPerform

    include CoinsMine
    include CoinsStorage
    include UnitsProduction
    include BuildingsProduction
    include BattleMessagesProxy

    attr_reader :username, :id, :units

    finalizer :drop_player

    UPDATE_PERIOD = 1
    SERIALIZATION_PERIOD = 180

    map_request RECEIVE_UNIT_PRODUCTION_TASK_ACTION, :unit_production_task_action
    map_request RECEIVE_BUILDING_PRODUCTION_TASK_ACTION, :building_production_task_action
    map_request RECEIVE_REQUEST_CURRENT_MINE_AMOUNT, :request_current_mine_amount
    map_request RECEIVE_DO_HARVESTING_ACTION, :do_harvesting_action
    map_request RECEIVE_NEW_BATTLE_ACTION, :new_battle_action
    map_request RECEIVE_RESPONSE_BATTLE_INVITE_ACTION, :response_battle_invite_action
    map_request RECEIVE_BATTLE_START_ACTION, :battle_start_action
    map_request RECEIVE_LOBBY_DATA_ACTION, :lobby_data_action
    map_request RECEIVE_PING_ACTION, :ping_action
    map_request RECEIVE_SPELL_CAST_ACTION, :cast_spell
    map_request RECEIVE_SPAWN_UNIT_ACTION, :spawn_unit

    def initialize( id, email, username, socket )
      @socket = socket
      @status = :run
      @id = id
      @email = email
      @username = username
      @latency = 0

      restore_from_redis

      # Buildings uids, assigned to coins generation
      @storage_building_uid = Storage::GameData.storage_building_uid
      @coin_generator_uid = Storage::GameData.coin_generator_uid

      compute_coins_gain
      compute_storage_capacity
      # Frozen player can't be invited to battle
      @frozen = false
      # Send game data to client
      send_game_data

      reset_gold_mine_notificator
      # Test this!
      Actor[:lobby].async.register(@id, @username)

      @update_timer = after(UPDATE_PERIOD) {
        async.update
      }

      @serialization_timer = after(SERIALIZATION_PERIOD) {
        async.serialize_player
      }
      # TODO: add inactivity timer

      restore_battle unless @battle_uid.nil?

      Actor["p_#{id}"] = Actor.current
    end

    def freeze!
      @frozen = true
    end

    def unfreeze!
      @frozen = false
    end

    def update
      current_time = Time.now.to_f
      # TODO: refactor production queue to Timers
      process_unit_queue current_time
      process_buildings_queue current_time

      send_ping

      @update_timer.reset
    end

    def restore_from_redis
      @redis_player_key = "players:#{@id}"
      @redis_resources_key = "#{@redis_player_key}:resources"

      units_json = nil
      buildings_json = nil
      units_queue = nil
      buildings_queue = nil

      Storage::Redis::Pool.connections_pool.with do |redis|
        units_json = redis.connection.hget(@redis_player_key, 'units')
        buildings_json = redis.connection.hget(@redis_player_key, 'buildings')
        units_queue = redis.connection.hget(@redis_player_key, 'units_queue')
        buildings_queue = redis.connection.hget(@redis_player_key, 'buildings_queue')

        @battle_uid = redis.connection.hget(@redis_player_key, 'battle_uid')

        @last_harvest_time = redis.connection.hget(@redis_resources_key, 'last_harvest_time').to_i
        @coins_in_storage = redis.connection.hget(@redis_resources_key, 'coins').to_i
        @harvester_storage = redis.connection.hget(@redis_resources_key, 'harvester_storage').to_i
      end

      @units = units_json.nil? ? {} : JSON.parse(units_json, {:symbolize_names => true})
      @buildings = buildings_json.nil? ? {} : JSON.parse(buildings_json, {:symbolize_names => true})
      @units_production_queue = units_queue.nil? ? {} : JSON.parse(units_queue, {:symbolize_names => true})
      @buildings_update_queue = buildings_queue.nil? ? {} : JSON.parse(buildings_queue, {:symbolize_names => true})
    end

    def serialize_player
      info "Save player (#{@id}) to redis..."

      Storage::Redis::Pool.connections_pool.with do |redis|
        # serialize units, buildings, coins, queue
        redis.connection.hset(@redis_player_key, 'units', JSON.generate(@units))
        redis.connection.hset(@redis_player_key, 'buildings', JSON.generate(@buildings))
        redis.connection.hset(@redis_player_key, 'units_queue', JSON.generate(@units_production_queue))
        redis.connection.hset(@redis_player_key, 'buildings_queue', JSON.generate(@buildings_update_queue))

        redis.connection.hset(@redis_player_key, 'battle_uid', @battle_uid)

        redis.connection.hset(@redis_resources_key, 'last_harvest_time', @last_harvest_time)
        redis.connection.hset(@redis_resources_key, 'coins', @coins_in_storage)
        redis.connection.hset(@redis_resources_key, 'harvester_storage', @harvester_storage)
      end

      @serialization_timer.reset
    end

    def disconnect
      @socket.close
      @status = :term

      @update_timer.cancel
      @serialization_timer.cancel
      @mine_notificator_timer.cancel unless @mine_notificator_timer.nil?

      serialize_player

      terminate
    end

    def drop_player
      Actor[:lobby].async.remove @id

      info "Terminating player (id = #{@id})"
    end

    # Sync player after battle
    # -add earned points
    # -decrease units count
    # -other...
    def sync_after_battle data
      data[:units].each do |uid, unit_data|
        @units[uid] -= unit_data[:lost]
        # Destroy field if no units left.
        if @units[uid] <= 0
          @units.delete(uid)
        end
      end
    end

    # Try to restore battle
    def restore_battle
      info "Player (#{@id}) try to restore battle..."

      battle = Actor[@battle_uid]
      if battle && battle.alive?

        info "Battle (@battle_uid) is in progress! Restoring..."

        create_new_battle_on_client battle.battle_initialization_data

        opponents = battle.opponents

        opponents.each do |player_id, player|
          player.path_ways.flatten.each do |unit|
            data = [unit.uid, unit.name, player_id, unit.path_id]
            send_unit_spawning data
          end
        end

        attach_to_battle @battle_uid
        send_custom_event :startBattle

        opponents.each_value do |opponent|
          opponent.path_ways.flatten.each {|unit| unit.force_sync = true }
        end

      end
    end

  end
end