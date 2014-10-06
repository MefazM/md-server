require 'battle/unit'
require 'battle/building'
require 'battle/opponent'
require 'battle/unit'
require 'battle/unit'
require 'battle/spells/spells_factory'

module Battle
  class BattleDirectorAi < BattleDirector
    # [:circle_fire,
    # :circle_earth,
    # :circle_water,
    # :arrow_air,
    # :arrow_water,
    # :arrow_earth,
    # :arrow_fire,
    # :z_water,
    # :z_air,
    # :z_fire,
    # :rect_air,
    # :rect_water]
    AI_ACTIONS = [:ai_heal, :ai_buff, :ai_debuff, :ai_atk_spell, :ai_spawn_unit]
    def set_ai_opponent ai_preset
      info "BattleDirector| added AI opponent preset: #{ai_preset[:name]}"

      @ai_preset = ai_preset
      @ai_opponent_id = "ai#{rand(0...99999)}"

      ai_opponent = Opponent.new({
        :id => @ai_opponent_id,
        :units => @ai_preset[:units],
        :level => @ai_preset[:level],
        :username => @ai_preset[:name],
        :is_ai => true
      })

      ai_opponent.ready!

      push_opponent ai_opponent
    end

    def notificate_player_achievement!(player_id, uid, value)
      unless @ai_opponent_id == player_id
        Actor["p_#{player_id}"].async.send_notification( uid, value )
      end
    end

    def start!
      super

      @ai_update_time = every(@ai_preset[:activity_period]) do
        send AI_ACTIONS.sample unless ENV['DEBUG']
        # send :ai_spawn_unit
      end
    end

    def finish_battle! loser_id
      @ai_update_time.cancel

      super
    end

    def ai_heal
      ai_boy = @opponents[@ai_opponent_id]
      matched_path_way = ai_boy.units_at_front( 20 ) do |unit|
        unit.low_hp? 0.6
      end

      unless matched_path_way.nil?
        position, matches = matched_path_way

        spell_uid = @ai_preset[:heal].sample
        if matches > 1
          ai_cast_spell(@ai_opponent_id, position, spell_uid)
        end
      end
    end

    def ai_buff
      ai_boy = @opponents[@ai_opponent_id]
      matched_path_way = ai_boy.units_at_front 15

      unless matched_path_way.nil?
        position, matches = matched_path_way

        spell_uid = @ai_preset[:buff].sample
        if matches > 3
          ai_cast_spell(@ai_opponent_id, position, spell_uid)
        end
      end
    end

    def ai_debuff
      opponent_id = @opponents_indexes[@ai_opponent_id]
      opponent = @opponents[opponent_id]

      matched_path_way = opponent.units_at_front(20)

      unless matched_path_way.nil?
        position, matches = matched_path_way

        spell_uid = @ai_preset[:debuff].sample
        if matches > 2
          ai_cast_spell(@ai_opponent_id, 1.0 - position, spell_uid)
        end
      end
    end

    def ai_atk_spell
      opponent_id = @opponents_indexes[@ai_opponent_id]
      opponent = @opponents[opponent_id]

      matched_path_way = opponent.units_at_front 40

      unless matched_path_way.nil?
        position, matches = matched_path_way

        spell_uid = @ai_preset[:atk_spell].sample
        if matches > 2
          ai_cast_spell(@ai_opponent_id, 1.0 - position, spell_uid)
        end
      end
    end

    def ai_spawn_unit
      unit_name = @ai_preset[:units].keys.sample
      spawn_unit(unit_name, @ai_opponent_id)

      # spawn_unit(@ai_preset[:units].keys.sample, @opponents_indexes[@ai_opponent_id])
    end

    def ai_cast_spell(ai_id, target, spell_uid)
      spell_data = Storage::GameData.spell_data spell_uid
      cast_spell(ai_id, target, spell_data)
    end

  end
end