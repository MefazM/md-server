module Player
  module BattleMessagesProxy

    # def current_battle

    #   return nil if @battle_uid_key.nil?

    #   battle = Celluloid::Actor[@battle_uid_key]

    #   if battle && battle.alive?
    #     return battle
    #   end

    #   nil
    #   # rescue Celluloid::DeadActorError
    #   #   warn "Accessing to dead battle actor (#{@battle_uid_key})"
    #   #   nil
    # end

    # def attach_to_battle battle_channel
    #   @battle_channel = battle_channel
    #   info "Player #{id} subscribe to #{@battle_channel}"
    #   subscribe(@battle_channel, :receive_message_from_battle_director)
    # end

    def attach_to_battle battle_uid
      @battle_channel = "#{battle_uid}_ch"
      @battle_uid_key = "battle_#{battle_uid}"
      @battle = Celluloid::Actor[@battle_uid_key]

      info "Player #{id} subscribe to #{@battle_channel}"
      subscribe(@battle_channel, :receive_message_from_battle_director)
    end

    def detach_from_battle
      info "Player #{id} unsubscribe from #{@battle_channel}"
      unsubscribe @battle_channel
      @battle_channel = nil
      @battle_uid_key = nil
    end

    def receive_message_from_battle_director(topic, payload)
      # info "New message from #{@battle_channel} = #{payload.inspect}"
      action, *data = payload

      case action
      when :sync_battle

        send_battle_sync payload[1]
      when :spawn_unit

        send_unit_spawning data
      when :battle_data

        send_create_new_battle_on_client data
      when :start_battle

        send_start_battle
      end

    end
  end
end