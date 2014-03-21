module Networking
  module Player
    def send_game_data

      buildings = {}

      @buildings.each do |uid, level|
        buildings[uid] = {:level => level, :ready => true, :uid => uid}
      end

      # buildings_queue = BuildingsFactory.instance.buildings_in_queue(@id)

      # buildings_queue.each do |uid, data|
      #   buildings[uid] = data
      #   # mark as not ready building in queue
      #   buildings[uid][:ready] = false
      # end

      # units_queue = UnitsFactory.instance.units_in_queue(@id)

      game_data = {
        :uid => @id,
        :player_data => {
          :coins_in_storage => @coins_in_storage,
          :storage_capacity => @storage_capacity,
          :buildings => buildings,
          :units => {
            :queue => {}#units_queue
          }
        },
        :game_data => Storage::GameData.collected_data,
        :server_version => 1101 #Settings::SERVER_VERSION
      }

      write_data [SEND_GAME_DATA_ACTION, @latency, game_data]
    end

    def write_data(data)
      json = JSON.generate(data)
      @socket.write "__JSON__START__#{json}__JSON__END__"
    end
  end
end