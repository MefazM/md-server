
require 'networking'

module Player
  class PlayerActor
    include Celluloid
    include Celluloid::IO
    include ::Networking::Player

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

      Storage::Redis::Pool.connections_pool.with do |redis|
        units_json = redis.connection.hget(@redis_player_key, 'units')
        buildings_json = redis.connection.hget(@redis_player_key, 'buildings')
        @last_harvest_time = redis.connection.hget(@redis_resources_key, 'last_harvest_time')
        @coins_in_storage = redis.connection.hget(@redis_resources_key, 'coins')
        @harvester_storage = redis.connection.hget(@redis_resources_key, 'harvester_storage')
      end

      @units = units_json.nil? ? {} : JSON.parse(units_json, {:symbolize_names => true})
      @buildings = buildings_json.nil? ? {} : JSON.parse(buildings_json, {:symbolize_names => true})

      # Buildings uids, assigned to coins generation
      @storage_building_uid = Storage::GameData.storage_building_uid
      @coin_generator_uid = Storage::GameData.coin_generator_uid

      compute_coins_gain
      compute_storage_capacity

      # Frezen player can't be invited to battle
      @frozen = false

      # Send game data to client
      send_game_data
    end

    # Update coin amount
    def compute_coins_gain
      level = @buildings[@coin_generator_uid] || 0
      data = Storage::GameData.harvester(level)

      @coins_gain = data[:amount]
      @harvester_capacity = data[:harvester_capacity]
    end

    # Update coins storage space
    def compute_storage_capacity
      level = @buildings[@storage_building_uid] || 0
      @storage_capacity =  Storage::GameData.storage_capacity(level)
    end

    def run

      # async._dispatch
      async._listen

    end

    def _listen
      loop {
        data = @socket.readpartial(4096)
        puts("***#{data.inspect}")
      }


      rescue EOFError
        # puts "*** #{host}:#{port} disconnected"
        @socket.close
        @status = :term
        puts "ASDASDASD!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
      # end
    end

    def _dispatch

      loop {

        return if @status == :term
        dd = rand(5) * 0.5
        @socket.write "Sleep for: #{dd}\n\r"

        results = Storage::Mysql::Pool.connections_pool.with do |conn|
          conn.query("SELECT * FROM units WHERE id=3").first
        end

        redis_results = Storage::Redis::Pool.connections_pool.with do |redis|
          redis.connection.hget("players:44:resources", "coins")
        end

        puts("#{@uid} MS: #{results[:name]}")
        puts("#{@uid} REDIS: #{redis_results.inspect}")
      }

    end
  end
end