class PlayerFactory
  include Singleton

  def initialize()
    @players = {}
    @connections = {}
    @storage_building_uid = GameData.instance.storage_building_uid
    @coin_generator_uid = GameData.instance.coin_generator_uid
  end

  def find_or_create(login_data, connection)
    login_data.map {|k,v| login_data[k] = DBConnection.escape(v)}
    MageLogger.instance.info "Player login. Token = #{login_data[:token]}"
    player = get_player_by_token(login_data[:token])

    if !player
      MageLogger.instance.info "Player not found. Create new..."
      player = create_player(login_data)
    end

    player_id = player.id()

    unless @connections[player_id].nil?
      @connections[player_id].close_connection
      @connections[player_id] = nil
    end
    # Save connection
    @connections[player_id] = connection
    # Assign player to connection
    connection.player= player

    player_id
  end

  def player(player_id)
    if @players.key? player_id
      @players[player_id]
    else
      data = DBConnection.query("SELECT * FROM players WHERE id = '#{player_id}' ").first

      return nil if data.nil?

      player = Player.new(data[:id], data[:email], data[:username])
      @players[player.id()] = player

      return player
    end
  end

  def connection(player_id)
    connection = @connections[player_id]
    if connection.nil?
      MageLogger.instance.info "PlayerFactory| Connection not found ##{player_id}"
    end

    connection
  end

  def appropriate_players_for_battle(player_id)
    players = []
    @connections.each_key do |id|
      players << [@players[id].id, @players[id].username]  unless id == player_id
    end

    players
  end

  def brodcast_ping(current_time)
    @connections.each do |key, connection|
      connection.send_ping( current_time )
    end
  end

  def brodcast_mine_capacity(current_time)
    @connections.each do |key, connection|
      amount = @players[key].mine_amount(current_time)
      capacity = @players[key].harvester_capacity
      # Send notification about gold mine overflow
      if amount >= capacity
        connection.send_gold_mine_storage_full()
      end
    end
  end

  def update_building(player_id, building_uid, level)
    player = @players[player_id]
    return false if player.nil?

    player.add_or_update_building(building_uid, level)
    # Notify client about task finished
    connection = connection(player_id)
    unless connection.nil?
      connection.send_sync_building_state(building_uid, level, true)
      # Handle special after-update rule for
      # storage and gold generator buildings
      if building_uid.to_sym == @storage_building_uid
        player.compute_storage_capacity()
        #Send new values
        connection.send_coins_storage_capacity(player.coins_in_storage, player.storage_capacity)
      elsif building_uid.to_sym == @coin_generator_uid
        player.compute_coins_gain()
        #Send new values
        connection.send_coins_storage_capacity(player.coins_in_storage, player.storage_capacity)
      end
    end
  end

private
  def get_player_by_token(token)
    player = nil
    authentication = DBConnection.query("SELECT * FROM authentications WHERE token = '#{token}' ").first
    if authentication
      player_id = authentication[:player_id]
      player = player(player_id)
    end

    return player
  end

  def create_player(login_data)
    player_id = Player.create(login_data)
    player(player_id)
  end

end