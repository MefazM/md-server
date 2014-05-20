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

        return true
      end

      # Set actual player status
      @status = :in_battle

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
      send_create_new_battle_on_client(data[:units_data][@id], data[:shared_data])
    end

    def finish_battle data
      send_finish_battle(data[:loser_id])

      unfreeze!

      sync_after_battle data[@id]

      detach_from_battle

      @status = :run
    end

  end
end