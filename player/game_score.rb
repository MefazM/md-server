module Player
  module GameScore

    def update_score data
      @data = data
      @score_settings = Storage::GameData.battle_score_settings
      @battle_score = 0
      @battle_coins = 0
      @achievement_score = 0
      @opponent_id = nil
      @battle_time = data[:battle_time]
      @is_winner = (@id == data[:winner_id])

      level = @level

      @stat = {
        :battle_time => @battle_time,
        :units_killed => 0,
        :units_killed_score => 0,
        :is_winner => @is_winner,
        :static_win => 0,
        :opponent_name => "",
        :modificator => 0,
        :spells => [],
        :score => 0,
        :score_sum => 0,
        :coins => 0
      }

      #################### \
      @opponent_id = determine_opponent!
      @stat[:opponent_name] = data[@opponent_id][:username]

      @stat[:modificator] = score_modificator = calculate_score_modificator_for(@opponent_id)
      #################### /

      #################### \
      spells_score, spells_statistics = calculate_spells_score_for(@id)
      #################### /

      #################### \
      units_score, units_killed = calculate_killed_units_score_for(@opponent_id)
      #################### /

      #################### \
      @achievement_score += calculate_time_bonus + spells_score

      if @is_winner
        @battle_score = (calculate_static_level_reward * winner_level + units_score + @achievement_score) * score_modificator
      else
        @battle_score = (calculate_static_level_reward * winner_level) * Storage::GameData.loser_modifier + units_score
      end
      @battle_score *= Storage::GameData.game_rate

      @stat[:score] = @battle_score.to_i
      @stat[:coins] = calcuate_coins(@battle_score).to_i
      @score += @stat[:score]
      @stat[:score_sum] = @score
      #################### /
      #################### \
      add_extra_gold(@stat[:coins])
      send_coins_storage_capacity
      #################### /

      #################### \
      level = calculate_current_level
      update_level_if_necessary(level)
      #################### /

      @stat
    end

    def determine_opponent!
      if @is_winner
         @data[:loser_id]
      elsif @id == @data[:loser_id]
        @data[:winner_id]
      else
        raise "Data corruption @ after_battle score calculation!"
      end
    end

    def calcuate_coins(coins)
      coins * Storage::GameData.score_to_coins_modifier
    end

    def update_level_if_necessary(level)
      if level > @level

        @level = level

        @stat[:levelup] = Storage::GameData.player_levels[@level]
        @stat[:levelup][:level] = @level
      end
    end

    def calculate_score_modificator_for(player_id)
      opponent_level = @data[player_id][:level]
      opponent_level = opponent_level.zero? ? 1 : opponent_level
      level = @level.zero? ? 1 : @level

      opponent_level / level
    end

    def calculate_spells_score_for(player_id)
      score = 0
      spells_grouped = {}
      spells_statistics = []

      @data[player_id][:spells].each { |uid| spells_grouped[uid] = spells_grouped[uid].to_i + 1 }
      # calculate score for each spell
      spells_grouped.each do |uid, times|

        spell_score = @score_settings[uid][:score_price] * times

        unless spell_score.nil?
          spells_statistics << {
            :name => uid,
            :count => times,
            :score => spell_score
          }

          score += spell_score
        end
      end

      @stat[:spells] = spells_statistics

      [score, spells_statistics]
    end

    def calculate_killed_units_score_for(player_id)
      units_score = 0
      units_killed = 0

      @data[player_id][:units].each do |uid, unit_data|
        units_score += @score_settings[uid][:score_price] * unit_data[:lost]

        units_killed += unit_data[:lost]
      end

      @stat[:units_killed] += units_killed
      @stat[:units_killed_score] += units_score

      [units_score, units_killed]
    end

    def calculate_time_bonus
      if @battle_time > @score_settings[:fast_battle][:time_period]
        fast_battle_score = @score_settings[:fast_battle][:score_price]

        @stat[:fast_battle] = fast_battle_score

        return fast_battle_score
      end

      0
    end

    def calculate_static_level_reward
      static_win_score = Storage::GameData.battle_reward winner_level
      @stat[:static_win] = static_win_score if @is_winner

      static_win_score
    end

    def winner_level
      @data[@data[:winner_id]][:level]
    end

    def score_sync_data
      level_at = Storage::GameData.next_level_at @level

      prev_level_at = if @level == 0
        0
      else
        prev_level_at = Storage::GameData.next_level_at prev_level
      end

      {
        :score => @score,#4
        :level_at => level_at - prev_level_at,
        :level => @level,
        :level_score => @score - prev_level_at
      }
    end

    def prev_level
      [0, @level].min
    end

    def calculate_current_level
      # Storage::GameData.player_levels.rindex{|score| @score > score[:level_at] } || 0
      level = 0
      Storage::GameData.player_levels.each{|score| level+=1 if @score > score[:level_at] }

      level
    end

    def send_score_sync
      sync_data = score_sync_data.values.unshift :syncScore
      # send_custom_event([:syncScore, @score, next_level_at, @level])
      send_custom_event sync_data
    end

  end
end