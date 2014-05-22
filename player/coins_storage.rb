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
      @coins_in_storage -= coins if enough_coins

      enough_coins
    end
  end
end