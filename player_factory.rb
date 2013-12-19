require 'pry'
require_relative 'db_connection.rb'
require_relative 'player.rb'
require_relative 'mage_logger.rb'

class PlayerFactory

  @@players = {}
  @@connections = {}

  def self.find_or_create(login_data, connection = nil)
    login_data.map {|k,v| login_data[k] = DBConnection.escape(v)}
    MageLogger.instance.info "Player login. Token = #{login_data[:token]}"
    player = get_player_by_token(login_data[:token])
    if !player
      MageLogger.instance.info " Not found. Create new..."
      player = create_player(login_data)
    end
    @@connections[player.get_id()] = connection unless connection.nil?

    player.get_id()
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
      player = Player.new(data[:id], data[:email], data[:username])

      @@players[player.get_id()] = player

      player
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
    DBConnection.query(
      "INSERT INTO players (email, username)
      VALUES ('#{login_data[:email]}', '#{login_data[:name]}')"
    )

    player_id = DBConnection.last_inser_id

    DBConnection.query(
      "INSERT INTO authentications (player_id, provider, token)
      VALUES (#{player_id}, '#{login_data[:provider]}', '#{login_data[:token]}')"
    )

    MageLogger.instance.info "New player created. id = #{player_id}"

    get_player_by_id(player_id)
  end

end