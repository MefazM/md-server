module Player
  module CoinsStorage

    def storage_full?
      @coins_in_storage >= @storage_capacity
    end

    # Update coins storage space
    def compute_storage_capacity
      level = @buildings[@storage_building_uid] || 0
      @storage_capacity =  Storage::GameData.storage_capacity(level)
    end

    def make_payment coins
      enough_coins = @coins_in_storage >= coins
      if enough_coins
        @coins_in_storage -= coins
        # Save left coint num here
        # redis_set(@redis_resources_key, 'coins', @coins_in_storage)
      end

      enough_coins
    end
  end
end