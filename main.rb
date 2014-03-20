#!/usr/bin/env ruby

require 'celluloid'
require 'celluloid/io'
require 'celluloid/autostart'

require 'pry'

require 'constants'
require 'storage'
require 'player'

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
    @server.close if @server
  end

  def run
    loop { async.handle_connection @server.accept }
  end

  def handle_connection(socket)
    _, port, host = socket.peeraddr

    puts "Received connection from #{host}:#{port}"

    player = Player.new(socket)
    player.async.run
  end
end

supervisor = GameServer.supervise( SERVER_HOST, SERVER_PORT )
trap("INT") { supervisor.terminate; exit }
sleep
