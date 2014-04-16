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

Celluloid.logger = nil

GameStatistics.new

class GameServer
  include Celluloid::IO
  include Celluloid::Logger
  include Player

  finalizer :shutdown

  def initialize(host, port)
    info "***Starting server on #{host}:#{port}. Ver.- #{SERVER_VERSION}.***"

    Storage::Mysql::Pool.create!
    Storage::Redis::Pool.create!
    Storage::GameData.load!

    @server = Celluloid::IO::TCPServer.new(host, port)

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

    request = Networking::Request.new socket

    player = nil

    request.listen_socket do |action, data|

      if action == Networking::Actions::RECEIVE_PLAYER_ACTION

        player_id, email, username = PlayerFactory.find_or_create data[0]

        player = PlayerActor.new(player_id, email, username, socket)

      elsif player.nil? == false

        player.async.perform(action, data)
      end

      false
    end

    rescue EOFError
      socket.close
  end
end

Lobby.new

supervisor = GameServer.supervise( SERVER_HOST, SERVER_PORT )
trap("INT") { supervisor.terminate; exit }
sleep
