require 'battle/unit'
require 'battle/ai_player'
require 'battle/building'
require 'battle/opponent'
require 'battle/unit'
require 'battle/unit'
require 'battle/spells/spells_factory'
require 'game_statistics/statistics_methods'

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

    AI_UPDATE_TIME = 1.5

    AI_ACTIONS = [:ai_heal, :ai_buff, :ai_debuff, :ai_atk_spell, :ai_spawn_unit]

    def set_ai_opponent data
      info "BattleDirector| added AI opponent. ID = #{data[:id]}"

      ai_opponent = Opponen.new data
      ai_opponent.ready!


      @ai_opponent_id = ai_opponent.id

      push_opponent ai_opponent
    end

    def notificate_player_achievement!(player_id, uid, value)
      unless @ai_opponent_id == player_id
        Actor["p_#{player_id}"].async.send_custom_event([:showAchievement, uid, value])
      end
    end

    def start!
      super

      @ai_update_time = after(AI_UPDATE_TIME) {
        action = AI_ACTIONS.sample
        send action

        @ai_update_time.reset
      }
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

        spell_uid = [:circle_earth, :arrow_earth].sample
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

        spell_uid = [:arrow_fire, :arrow_air].sample
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

        spell_uid = [:z_water, :rect_air, :arrow_water, :rect_water, :z_fire].sample
        if matches > 2
          ai_cast_spell(@ai_opponent_id, 1.0 - position, spell_uid)
        end
      end
    end

    # def cast_spell_on_player segment_length, min_matches, spell_uid
    #   ai_boy = @opponents[@ai_opponent_id]
    #   matched_path_way = ai_boy.units_at_front segment_length

    #   unless matched_path_way.nil?
    #     position, matches = matched_path_way
    #     if matches > min_matches
    #       ai_cast_spell(@ai_opponent_id, position, spell_uid)
    #     end
    #   end
    # end

    # def cast_spell_on_ai segment_length, min_matches, spell_uid
    #   opponent_id = @opponents_indexes[@ai_opponent_id]
    #   opponent = @opponents[opponent_id]

    #   matched_path_way = opponent.units_at_front segment_length

    #   unless matched_path_way.nil?
    #     position, matches = matched_path_way

    #     if matches > min_matches
    #       ai_cast_spell(@ai_opponent_id, 1.0 - position, spell_uid)
    #     end
    #   end
    # end

    def ai_atk_spell
      opponent_id = @opponents_indexes[@ai_opponent_id]
      opponent = @opponents[opponent_id]

      matched_path_way = opponent.units_at_front 40

      unless matched_path_way.nil?
        position, matches = matched_path_way

        spell_uid = [:z_air, :circle_water, :circle_fire].sample
        if matches > 2
          ai_cast_spell(@ai_opponent_id, 1.0 - position, spell_uid)
        end
      end
    end

    def ai_spawn_unit
      unit_name = ['crusader', 'mage', 'elf'].sample
      spawn_unit(unit_name, @ai_opponent_id, false)
    end

    def ai_cast_spell(ai_id, target, spell_uid)
      spell_data = Storage::GameData.spell_data spell_uid
      cast_spell(ai_id, target, spell_data)
    end

  end
end