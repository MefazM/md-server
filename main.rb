#!/usr/bin/env ruby

require 'celluloid'
require 'celluloid/io'
require 'celluloid/autostart'

require 'pry'

require 'json'

require 'constants'
require 'storage'

require 'player_factory'

require 'networking'



class GameServer
  include Celluloid::IO
  include Celluloid::Logger

  finalizer :shutdown

  def initialize(host, port)
    info "***Starting server on #{host}:#{port}. Ver.- #{SERVER_VERSION}.***"

    Storage::Mysql::Pool.create!
    Storage::Redis::Pool.create!

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
      if action == Networking::RECEIVE_PLAYER_ACTION
        Player::PlayerFactory.find_or_create(data[0], socket).async.run

        true
      end
    end

    rescue EOFError
      socket.close
  end
end

supervisor = GameServer.supervise( SERVER_HOST, SERVER_PORT )
trap("INT") { supervisor.terminate; exit }
sleep
