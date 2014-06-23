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
        Celluloid::Logger::error <<-MSG
          Can't execute battle message handler #{handler}
          #{e}
          #{e.backtrace.join('\n')}
        MSG
    end

    def create_new_battle_on_client data
      send_create_new_battle_on_client(data[:units_data][@id], data[:shared_data], data[:mana_data][@id])
    end

    def finish_battle data
      # TODO: send sync data in one action!
      send_custom_event([:finishBattle, update_score(data)])

      remove_killed_units! data[@id][:units]

      @status = :run

      unfreeze!

      compute_mana_storage

      send_sync_mana_storage

      send_score_sync

      detach_from_battle
    end

    def remove_killed_units! lost_units_data
      # Sync lost units data
      lost_units_data.each do |uid, unit_data|
        @units[uid] -= unit_data[:lost]
        # Destroy field if no units left.
        @units.delete(uid) if @units[uid] < 1
      end
    end

  end
end