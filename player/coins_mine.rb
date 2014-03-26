module Player
  module CoinsMine

    # Update coin amount
    def compute_coins_gain
      level = @buildings[@coin_generator_uid] || 0
      data = Storage::GameData.harvester(level)

      @coins_gain = data[:amount]
      @harvester_capacity = data[:harvester_capacity]
    end

    def reset_gold_mine_full_notification
      d_time = Time.now.to_i - @last_harvest_time

      @harvester_capacity

      coins_amount = (d_time * @coins_gain).to_i + @harvester_storage

      d_amount = @harvester_capacity - coins_amount

      time_left = d_amount / @coins_gain

      unless @gold_mine_notification_timer.nil?
        @gold_mine_notification_timer.cancel
        @gold_mine_notification_timer = nil
      end

      if time_left > 0.0
        @gold_mine_notification_timer = @timers.after(time_left) {
          send_gold_mine_storage_full
        }

      else
        send_gold_mine_storage_full
      end

    end

    def harvest
      current_time = Time.now.to_i
      d_time = current_time - @last_harvest_time
      earned = (d_time * @coins_gain).to_i

      @harvester_storage += earned

      if @harvester_storage > @harvester_capacity
        @harvester_storage = @harvester_capacity
      end

      @coins_in_storage += @harvester_storage

      if @coins_in_storage >= @storage_capacity
        @harvester_storage = @coins_in_storage - @storage_capacity
        @coins_in_storage = @storage_capacity
      else
        @harvester_storage = 0
      end

      @last_harvest_time = current_time

      reset_gold_mine_full_notification
    end

  end
end