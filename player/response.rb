module Player
  module Response
    include ::Networking::Actions

    def send_game_data

      buildings = {}

      @buildings.each do |uid, level|
        buildings[uid] = {:level => level, :ready => true, :uid => uid}
      end

      buildings_updates_queue_export.each do |building_uid, task|
        buildings[building_uid] = task
        buildings[building_uid][:ready] = false
      end

      game_data = {
        :uid => @id,
        :player_data => {
          :coins_in_storage => @coins_in_storage,
          :storage_capacity => @storage_capacity,
          :buildings => buildings,
          :units => {
            # restore unit production queue on client
            :queue => units_in_queue_export
          }
        },
        :game_data => Storage::GameData.collected_data,
        :server_version => 1101 #Settings::SERVER_VERSION
      }

      write_data [SEND_GAME_DATA_ACTION, @latency, game_data]
    end

    def send_coins_storage_capacity
      write_data [SEND_CUSTOM_EVENT, @latency, :setStorageCapacity,
        @coins_in_storage, @storage_capacity]
    end

    def send_current_mine_amount
      d_time = Time.now.to_i - @last_harvest_time
      amount = (d_time * @coins_gain).to_i + @harvester_storage

      write_data [SEND_CUSTOM_EVENT, @latency, :currentMineAmount,
        amount, @harvester_capacity, @coins_gain]
    end

    def send_gold_mine_storage_full
      write_data [SEND_CUSTOM_EVENT, @latency, :goldMineStorageFull]
    end

    def send_new_unit_queue_item(unit_uid, producer_id, production_time)
      write_data [SEND_PUSH_UNIT_QUEUE_ACTION, @latency, unit_uid,
        producer_id, production_time]
    end

    def send_start_unit_queue_task(producer_id, production_time)
      write_data [SEND_START_TASK_IN_UNIT_QUEUE_ACTION, @latency,
        producer_id, production_time]
    end

    def send_sync_building_state(uid, level, is_ready = true, finish_time = nil)
      message = [SEND_SYNC_BUILDING_STATE_ACTION, @latency, uid, level, is_ready]
      message << finish_time unless is_ready

      write_data message
    end

    def send_invite_to_battle(token, sender_id)
      write_data [SEND_INVITE_TO_BATTLE_ACTION, @latency, token, sender_id]
    end

    def send_custom_event event_data
      message = [SEND_CUSTOM_EVENT, @latency]
      if event_data.kind_of?(Array)
        message += event_data
      else
        message << event_data
      end

      write_data message
    end

    def send_lobby_data(players_data, ai_oppontns_data)
      write_data [SEND_LOBBY_DATA_ACTION, @latency, players_data, ai_oppontns_data]
    end

    def send_finish_battle loser_id
      write_data [SEND_FINISH_BATTLE_ACTION, @latency, loser_id]
    end

    # TODO: separate send_create_new_battle_on_client
    # into two methods
    #  1 - create_battle @ client
    #  2 - send_battle_data (useful on battle restore)
    # remove @id
    def send_create_new_battle_on_client(units, shared_data)
      write_data [SEND_CREATE_NEW_BATTLE_ON_CLIENT_ACTION, @latency, @id, units, shared_data]
    end

    def send_spell_cast spell_data
      write_data [SEND_SPELL_CAST_ACTION, @latency] + spell_data
    end

    def send_battle_sync sync_data
      write_data [SEND_BATTLE_SYNC_ACTION, @latency, sync_data]
    end

    def send_unit_spawning unit_data
      write_data [SEND_SPAWN_UNIT_ACTION, @latency] + unit_data
    end

    def send_ping
      write_data [SEND_PING_ACTION, @latency, Time.now.to_f]
    end

    def write_data data
      # puts data.inspect
      json = JSON.generate(data)

      @socket.write "__JSON__START__#{json}__JSON__END__"

      rescue Exception => e
        Celluloid::Logger::error e[0..20]
        disconnect
    end
  end
end