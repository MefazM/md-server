require 'pry'
require_relative 'db_connection.rb'
require_relative 'player.rb'
require_relative 'mage_logger.rb'

class PlayerFactory

  @@players = {}
  @@connections = {}

  def self.find_or_create(login_data, connection)
    login_data.map {|k,v| login_data[k] = DBConnection.escape(v)}
    MageLogger.instance.info "Player login. Token = #{login_data[:token]}"
    player = get_player_by_token(login_data[:token])

    if !player
      MageLogger.instance.info "Player not found. Create new..."
      player = create_player(login_data)
    end

    player_id = player.get_id()

    unless @@connections[player_id].nil?
      @@connections[player_id].close_connection
      @@connections[player_id] = nil
    end
    # assign connection
    @@connections[player_id] = connection

    player_id
  end

  def self.send_game_data(player_id, action = :request_player )
    connection = self.connection(player_id)
    connection.send_game_data({
      :uid => player_id,
      :player_data => @@players[player_id].get_game_data(),
      :game_data => GameData.instance.collected_data
    })
  end

  def self.get_player_by_id(player_id)
    if @@players.key? player_id
      @@players[player_id]
    else
      data = DBConnection.query("SELECT * FROM players WHERE id = '#{player_id}' ").first

      return nil if data.nil?

      player = Player.new(data[:id], data[:email], data[:username])
      @@players[player.get_id()] = player

      return player
    end
  end

  def self.connection(player_id)
    connection = @@connections[player_id]
    if connection.nil?
      MageLogger.instance.info "PlayerFactory| Connection not found ##{player_id}"
    end

    connection
  end


  def self.appropriate_players_for_battle(player_id)
    players = []
    @@connections.each_key do |id|
      players << @@players[id].to_i unless id == player_id
    end

    players
  end

  def self.brodcast_ping(current_time)
    @@connections.each do |key, connection|
      connection.send_ping( current_time )
    end
  end

  def self.harvest_coins(player_id)
    player = get_player_by_id(player_id)

    earned_coins = player.harvest

    connection = self.connection(player_id)
    connection.send_harvesting_results(earned_coins)
  end

private

  def self.get_player_by_token(token)
    player = nil
    authentication = DBConnection.query("SELECT * FROM authentications WHERE token = '#{token}' ").first
    if authentication
      player_id = authentication[:player_id]
      player = get_player_by_id(player_id)
    end

    return player
  end

  def self.create_player(login_data)
    player_id = Player.create(login_data)
    get_player_by_id(player_id)
  end

end