module Player
  module BattleMessagesProxy

    def attach_to_battle battle_uid
      battle_channel = "#{battle_uid}_ch"

      battle = Celluloid::Actor[battle_uid]

      if battle && battle.alive?
        info "Player #{id} subscribe to #{battle_channel}"

        subscribe(battle_channel, :receive_message_from_battle_director)

        @battle_uid = battle_uid
        @battle = battle

        @status = :in_battle
        return true
      end

      # Set actual player status
      false
    end

    def detach_from_battle
      unsubscribe "#{@battle_uid}_ch"

      @battle_uid = nil
      @battle = nil
    end

    def receive_message_from_battle_director(topic, payload)
      handler, *data = payload
      args = data.length > 1 ? data : data[0]

      send(handler, args)

      rescue Exception => e
        Celluloid::Logger::error "Can't execute battle message handler #{handler} \n #{e}"
    end

    def create_new_battle_on_client data
      send_create_new_battle_on_client(data[:units_data][@id], data[:shared_data], data[:mana_data][@id])
    end

    def finish_battle data
      send_finish_battle(data[:loser_id])
      # Sync player after battle
      # -add earned points
      # -decrease units count
      # -other...
      data[@id][:units].each do |uid, unit_data|
        @units[uid] -= unit_data[:lost]
        # Destroy field if no units left.
        if @units[uid] <= 0
          @units.delete(uid)
        end
      end

      @status = :run

      unfreeze!

      compute_mana_storage
      send_custom_event mana_sync_data

      detach_from_battle
    end

  end
end