module Player
  module RedisMapper

    def restore_from_redis
      @redis_player_key = "players:#{@id}"
      @redis_resources_key = "#{@redis_player_key}:resources"

      current_time = Time.now.to_i
      # ебааааать
      read_redis_attrs(@redis_player_key, {
        :units => {},
        :buildings => {},
        :units_queue => {},
        :buildings_queue => {}
      }) do |value|
        JSON.parse(value, {:symbolize_names => true})
      end


      read_redis_attrs(@redis_resources_key, {
        :last_harvest_time => current_time,
        :coins_in_storage => 0,
        :harvester_storage => 0,
        :last_mana_compute_time => current_time,
        :mana_storage_value => 0,
        :battle_uid => nil
      }) do |value|
        value.to_i
      end

      read_redis_attrs(@redis_resources_key, { :battle_uid => nil })

    end

    def serialize_player
      info "Save player (#{@id}) to redis..."

      wright_redis_attrs(@redis_player_key, [
        :units,
        :buildings,
        :units_queue,
        :buildings_queue
      ]) do |value|
        JSON.generate(value)
      end

      wright_redis_attrs(@redis_resources_key, [
        :last_harvest_time,
        :coins_in_storage,
        :harvester_storage,
        :last_mana_compute_time,
        :mana_storage_value,
        :battle_uid
      ])

      @serialization_timer.reset
    end

    private

    def read_redis_attrs(path, map)
      # raise "No block given!" unless block_given?
      map.each do |field_name, default_value|
        Storage::Redis::Pool.connections_pool.with do |redis|
          value = redis.connection.hget(path, field_name)

          if value.nil?
            value = default_value
          elsif block_given?
            value = yield(value)
          end

          instance_variable_set("@#{field_name}", value)
        end
      end
    end

    def wright_redis_attrs(path, map)
      # raise "No block given!" unless block_given?
      map.each do |field_name, default_value|
        Storage::Redis::Pool.connections_pool.with do |redis|
          value = instance_variable_get("@#{field_name}")
          value = yield(value) if block_given?

          redis.connection.hset(path, field_name, value)
        end
      end
    end

  end
end