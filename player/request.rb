module Player
  module RequestPerform

    def self.included(base)
      base.send :extend, ClassMethods
      # base.send :include, InstanceMethods
    end

    def self.map_request action, handler
      @@registered_actions ||= {}
      @@registered_actions["state_#{action}"] = handler
    end

    module ClassMethods
      def map_request action, handler
        Player::RequestPerform.map_request action, handler
      end
    end

    # module InstanceMethods
    def perform(action, payload)
      handler = @@registered_actions["state_#{action}"]

      if handler.nil?
        Celluloid::Logger::error "Can't perform action (state_#{action})"
        return
      end

      send(handler, payload)

      rescue Exception => e
        Celluloid::Logger::error <<-MSG
          Can't execute handler #{handler} for actions state_#{action}
          #{e}
          #{e.backtrace.join('\n')}
        MSG
    end

    #
    # RESPONSE HANDLERS

    # RECEIVE_UNIT_PRODUCTION_TASK_ACTION
    def unit_production_task_action payload
      unit_uid = payload[0].to_sym
      unit = Storage::GameData.unit unit_uid

      building_uid = unit[:depends_on_building_uid]
      building_level = unit[:depends_on_building_level]
      price = unit[:price]
      # TODO: add building_is_ready velidation here
      buiding_exist = @buildings[building_uid].nil? ? false : @buildings[building_uid] >= building_level

      if buiding_exist

        if make_payment price
          production_time = unit[:production_time]

          add_unit_production_task(unit_uid, production_time, building_uid)

          send_new_unit_queue_item(unit_uid, building_uid, production_time)

          send_coins_storage_capacity
        end
      end
    end

    # RECEIVE_BUILDING_PRODUCTION_TASK_ACTION
    def building_production_task_action payload
      building_uid = payload[0].to_sym
      # if player already construct this building, current level > 0
      level = @buildings[building_uid] || 0
      target_level = level + 1
      # TODO: add updateable validation here
      # TODO: add not_units_task to this building validation here
      building = Storage::GameData.building "#{building_uid}_#{target_level}"

      unless building.nil? and building_ready? building_uid
        price = building[:price]
        if make_payment price
          production_time_in_ms = building[:production_time] * 1000
          add_update_building_task(building_uid, building[:production_time], target_level)

          send_sync_building_state(building_uid, target_level, false, production_time_in_ms)

          send_coins_storage_capacity
        end
      end
    end

    # RECEIVE_REQUEST_CURRENT_MINE_AMOUNT
    def request_current_mine_amount payload
      send_current_mine_amount
    end

    # RECEIVE_DO_HARVESTING_ACTION
    def do_harvesting_action payload
      unless storage_full?
        earned = harvest
        send_coins_storage_capacity earned
      end
    end

    # RECEIVE_NEW_BATTLE_ACTION
    def new_battle_action payload
      # Is ai battle?
      if payload[1] == true
        # Celluloid::Actor[:lobby].start_ai_battle
        # BattleDirectorFactory.instance.create_ai_battle(@id, payload[0])
        Celluloid::Actor[:lobby].async.create_ai_battle(@id, payload[0])
      else

        Celluloid::Actor[:lobby].async.invite(@id, payload[0])
      end
    end

    # RECEIVE_RESPONSE_BATTLE_INVITE_ACTION
    def response_battle_invite_action payload
      info "Player ID = #{@id}, response to battle invitation. UID = #{payload[0]}."
      # payload[0] - uid, payload[1] - is decision
      Celluloid::Actor[:lobby].opponent_response_to_invitation(@id, payload[0], payload[1])
    end

    # RECEIVE_BATTLE_START_ACTION
    def battle_start_action payload
      @battle.set_opponent_ready(@id)
    end

    # RECEIVE_LOBBY_DATA_ACTION
    def lobby_data_action payload
      # Collect data for user battle lobby
      # TODO: REFACTOR THIS TO FUTURES!!!
      players = Celluloid::Actor[:lobby].players({
        :except => @id,
      })

      ai = Storage::GameData.ai_presets.map{|uid, preset|
        level = preset[:level] + @level
        level = 0 if level < 0

        [uid, preset[:name], level]
      }

      send_lobby_data(players, ai)
    end

    # RECEIVE_PING_ACTION
    def ping_action payload
      @latency = (Time.now.to_f - payload[0]).round(3)
    end
    # end

    def cast_spell_action payload
      uid, target = payload[0], payload[1]
      spell_data = Storage::GameData.spell_data uid
      if spell_data.nil?

        Celluloid::Logger::error "Spell (s: #{uid}, from player with id = #{@id}) not found."
        return false
      end

      if decreasre_mana(spell_data[:mana_cost])

        @battle.cast_spell(@id, target, spell_data)
      end
    end

    def spawn_unit payload
      @battle.spawn_unit(payload[0], @id)
    end

  end
end
