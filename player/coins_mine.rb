module Player
  module CoinsMine
    # Update coin amount
    def compute_coins_gain
      level = @buildings[@coin_generator_uid] || 0
      data = Storage::GameData.coins_harvester level

      @coins_gain = data[:amount]
      @harvester_capacity = data[:harvest_capacity]
    end

    def reset_gold_mine_notificator
      unless @mine_notificator_timer.nil?
        @mine_notificator_timer.cancel
        @mine_notificator_timer = nil
      end

      d_time = Time.now.to_i - @last_harvest_time
      coins_amount = (d_time * @coins_gain).to_i + @harvester_storage
      to_full = @harvester_capacity - coins_amount

      if to_full > 0.0
        to_full_time = to_full / @coins_gain

        @mine_notificator_timer = after(to_full_time) do
          send_gold_mine_storage_full
        end
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
        earned = @harvester_capacity
      end

      in_storage = @coins_in_storage + @harvester_storage

      if in_storage >= @storage_capacity
        @harvester_storage = in_storage - @storage_capacity
        @coins_in_storage = @storage_capacity
      else
        @coins_in_storage = in_storage
        @harvester_storage = 0
      end

      @last_harvest_time = current_time

      reset_gold_mine_notificator

      earned
    end

    def add_extra_gold coins_count
      @coins_in_storage += coins_count
      @coins_in_storage = @coins_in_storage.to_i

      if @coins_in_storage >= @storage_capacity
        @coins_in_storage = @storage_capacity
      end
    end

  end
end