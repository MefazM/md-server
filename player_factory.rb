require 'pry'
require_relative 'db_connection.rb'
require_relative 'player.rb'
require_relative 'mage_logger.rb'

class PlayerFactory

  @@players = {}

  def self.find_or_create(login_data)
    login_data.map {|k,v| login_data[k] = DBConnection.escape(v)}

    MageLogger.instance.info "Player login. Token = #{login_data[:token]}"

    player = get_player_by_token(login_data[:token])

    if !player
      MageLogger.instance.info " Not found. Create new..."
      player = create_player(login_data)
    end

    player
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