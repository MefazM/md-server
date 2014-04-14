#!/usr/bin/env ruby

require 'celluloid'
require 'celluloid/io'
require 'celluloid/autostart'
require 'pry'
require 'json'
require 'constants'
require 'storage/storage'
require 'player/player_factory'
require 'network/networking'
require 'lobby'

require 'game_statistics/game_statistics'




GameStatistics.new

class GameServer
  include Celluloid::IO
  include Celluloid::Logger

  finalizer :shutdown

  def initialize(host, port)
    info "***Starting server on #{host}:#{port}. Ver.- #{SERVER_VERSION}.***"

    Storage::Mysql::Pool.create!
    Storage::Redis::Pool.create!
    Storage::GameData.load!

    @server = TCPServer.new(host, port)
    async.run
  end

  def shutdown
    info "***Shutting down server...***"
    @server.close if @server
  end

  def run
    loop { async.handle_connection @server.accept }
  end

  def handle_connection(socket)
    _, port, host = socket.peeraddr

    info "Received connection from #{host}:#{port}"

    Networking::Request.listen_socket(socket) do |action, data|

      if action == Networking::Actions::RECEIVE_PLAYER_ACTION
        Player::PlayerFactory.find_or_create(data[0], socket).async.run

        true
      end
    end

    rescue EOFError
      socket.close
  end
end

Celluloid::Actor[:lobby] = Lobby.new

supervisor = GameServer.supervise( SERVER_HOST, SERVER_PORT )
trap("INT") { supervisor.terminate; exit }
sleep
