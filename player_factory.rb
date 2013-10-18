require 'pry'
require_relative 'db_connection.rb'
require_relative 'player.rb'

class PlayerFactory
  @@connections = {}

  def self.find_or_create(login_data, connection)
    login_data.map {|k,v| login_data[k] = DBConnection.escape(v)}
    print("Player login. Token = #{login_data[:token]}")
    player = get_player_by_token(login_data[:token])

    if !player
      print(" Not found. Create new...")
      player = create_player(login_data)
    end

    print(" OK!\n")

    @@connections[player.get_id()] = connection

    connection.set_player(player)
  end

  def self.get_appropriate_players (player_id)
    responce = []
    @@connections.each do |p_id, conn|
      responce << conn.get_player().to_hash() #if p_id != player_id
    end

    responce
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

  def self.get_player_by_id(player_id)
    data = DBConnection.query("SELECT * FROM players WHERE id = '#{player_id}' ").first
    player = Player.new()
    player.map_from_db(data)

    player
  end

  def self.create_player(login_data)
    DBConnection.query(
      "INSERT INTO players (email, username) 
      VALUES ('#{login_data[:email]}', '#{login_data[:name]}')"
    )

    player_id = DBConnection.last_inser_id

    DBConnection.query(
      "INSERT INTO authentications (user_id, provider, token) 
      VALUES (#{player_id}, '#{login_data[:provider]}', '#{login_data[:token]}')"
    )
    print(" OK! user id = #{player_id} \n")

    get_player_by_id(player_id)
  end

end