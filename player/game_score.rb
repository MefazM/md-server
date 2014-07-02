module Player
  module GameScore

    def update_score data
      score = 0
      opponent_id = nil
      battle_time = data[:battle_time]
      is_winner = @id == data[:winner_id]
      level = @level

      stat = {
        :battle_time => battle_time,
        :units_killed => 0,
        :units_killed_score => 0,
        :is_winner => is_winner
      }

      score_settings = Storage::GameData.battle_score_settings

      if is_winner
        # time bonus
        if battle_time > score_settings[:fast_battle][:time_period]
          fast_battle_score = score_settings[:fast_battle][:score_price]
          score += fast_battle_score

          stat[:fast_battle] = fast_battle_score
        end
        # static level reward
        static_win_score = Storage::GameData.battle_reward level
        stat[:static_win] = static_win_score
        score += static_win_score

        opponent_id = data[:loser_id]

      elsif @id == data[:loser_id]

        opponent_id = data[:winner_id]
      else

        raise "Data corruption @ after_battle score calculation!"
      end

      stat[:opponent_name] = data[opponent_id][:username]
      # Level modificator
      opponent_level = data[opponent_id][:level]
      score_modificator = opponent_level / level
      stat[:modificator] = score_modificator

      # Score for spells
      # group spells by type
      spells_grouped = Hash.new(0)
      data[@id][:spells].each {|uid| spells_grouped[uid] += 1 }
      spells_statistics = []
      # calculate score for each spell
      spells_grouped.each do |uid, times|

        spell_score = score_settings[uid][:score_price] * times

        unless spell_score.nil?
          spells_statistics << {
            :name => uid,
            :count => times,
            :score => spell_score
          }

          score += spell_score
        end
      end
      stat[:spells] = spells_statistics

      # process score income for each killed units
      data[opponent_id][:units].each do |uid, unit_data|

        unit_score = score_settings[uid][:score_price] * unit_data[:lost]

        score += unit_score

        stat[:units_killed] += unit_data[:lost]
        stat[:units_killed_score] += unit_score
      end

      score *= score_modificator * Storage::GameData.game_rate
      @score += score

      stat[:score] = score
      stat[:score_sum] = @score

      coins = score * 1.2

      add_extra_gold coins
      send_coins_storage_capacity

      stat[:coins] = coins

      level = calculate_current_level

      if level > @level

        @level = level

        stat[:levelup] = Storage::GameData.player_levels[@level]
        stat[:levelup][:level] = @level
      end

      stat
    end

    def score_sync_data
      level_at = Storage::GameData.next_level_at @level
      prev_level_at = Storage::GameData.next_level_at prev_level
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