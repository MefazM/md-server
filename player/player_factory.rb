require 'player/player'

module Player
  # TODO: Fix sql injection problem
  class PlayerFactory
    def self.find_or_create(login_data, socket)
      Celluloid::Logger::info "Player logging in (Token = #{login_data[:token]})"

      authentication = Storage::Mysql::Pool.connections_pool.with do |mysql|
        mysql.select("SELECT * FROM authentications WHERE token = '#{login_data[:token]}'").first
      end

      player_id = authentication.nil? ? self.create_player(login_data) : authentication[:player_id]
      actor_key = "p_#{player_id}"

      player = self.get_player(player_id, socket)

      # if Celluloid::Actor[actor_key]
      #   raise "Try to access alive player!" if Celluloid::Actor[actor_key].alive?
      # end

      Celluloid::Actor[actor_key] = player

      player
    end

    private

    def self.create_player(login_data)
      player_id = Storage::Mysql::Pool.connections_pool.with do |mysql|

        mysql.insert('players', {:email => login_data[:email], :username => login_data[:name]})

        id = mysql.last_inser_id

        raise "Player is not created! \n #{login_data.inspect}" if id == -1

        data = {:player_id => id, :provider => login_data[:provider],:token => login_data[:token]}
        mysql.insert('authentications', data)

        id
      end

      Celluloid::Logger::info "New player created. id = #{player_id}"

      Storage::Redis::Pool.connections_pool.with do |redis|
        redis.connection.hset("players:#{player_id}:resources", "last_harvest_time", Time.now.to_i)
        redis.connection.hset("players:#{player_id}:resources", 'coins', 0)
        redis.connection.hset("players:#{player_id}:resources", 'harvester_storage', 0)
      end

      player_id
    end

    def self.get_player(player_id, socket)
      player_data = Storage::Mysql::Pool.connections_pool.with do |mysql|
        mysql.select("SELECT * FROM players WHERE id = '#{player_id}' ").first
      end

      raise "Authentication find, but player data is not found!" if player_data.nil?

      return PlayerActor.new(player_id, player_data[:email], player_data[:username], socket)
    end

  end
end
