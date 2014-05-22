module Player
  module ManaStorage

    def compute_mana_storage
      mana_settings = Storage::GameData.mana_storage 1
      # @last_mana_compute_time

      amount_key = @status == :in_battle ? :amount_at_battle : :amount_at_shard
      amount_per_second = mana_settings[amount_key]

      current_time = Time.now.to_i
      d_time = current_time - @last_mana_compute_time
      @last_mana_compute_time = current_time

      @mana_storage_value += d_time * amount_per_second

      max_capacity = mana_settings[:capacity]
      if @mana_storage_value >= max_capacity
        @mana_storage_value = max_capacity
      end
    end

    def decreasre_mana value
      @mana_storage_value -= value
      compute_mana_storage
      send_sync_mana_storage
    end

  end
end