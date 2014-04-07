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

      # payload =_payload.dup

      # puts("\n\n (ID = #{@id}) \n ================ \n\n  #{payload.inspect}  \n\n ======================== \n\n")


      handler, *data = payload
      args = data.length > 1 ? data : data[0]

      # puts("\n\n (ID = #{@id}) \n AAAAAAAAAAAA!!!!!! \n\n H =     #{handler} \n\n DATA =     #{data.inspect} \n\n ")

      # binding.pry if :create_new_battle_on_client == handler

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

      @battle_channel = nil
      @battle_uid_key = nil
      @battle = nil
    end

  end
end