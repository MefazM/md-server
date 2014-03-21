
require 'player'

module Player
  class PlayerFactory

    def self.find_or_create(login_data, socket)
      Celluloid::Logger::info "Player logging in (Token = #{login_data[:token]})"

      authentication = Storage::Mysql::Pool.connections_pool.with do |mysql|
        mysql.query("SELECT * FROM authentications WHERE token = '#{login_data[:token]}'").first
      end

      player_id = authentication.nil? ? self.create_player(login_data) : authentication[:player_id]

      self.get_player(player_id, socket)
    end

    private

    def self.create_player(login_data)
      player_id = Storage::Mysql::Pool.connections_pool.with do |mysql|
        mysql.query("INSERT INTO players (email, username)
          VALUES ('#{login_data[:email]}', '#{login_data[:name]}')")

        id = mysql.last_inser_id

        mysql.query("INSERT INTO authentications (player_id, provider, token)
          VALUES (#{id}, '#{login_data[:provider]}', '#{login_data[:token]}')")

        id
      end

      Celluloid::Logger::info "New player created. id = #{player_id}"

      Storage::Redis::Pool.connections_pool.with do |redis|
        redis.hset("players:#{player_id}:resources", "last_harvest_time", Time.now.to_i)
        redis.hset("players:#{player_id}:resources", 'coins', 0)
        redis.hset("players:#{player_id}:resources", 'harvester_storage', 0)
      end

      player_id
    end

    def self.get_player(player_id, socket)
      player_data = Storage::Mysql::Pool.connections_pool.with do |mysql|
        mysql.query("SELECT * FROM players WHERE id = '#{player_id}' ").first
      end

      raise "Authentication find, but player data is not found!" if player_data.nil?

      return PlayerActor.new(player_id, player_data[:email], player_data[:username], socket)
    end

  end
end
