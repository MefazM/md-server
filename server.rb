#!/usr/bin/env ruby
require 'pry'
require 'rubygems'
require 'eventmachine'
require 'json'
require 'logger'

require_relative 'player.rb'
require_relative 'battle_director.rb'
require_relative 'db_resources.rb'

$db_resources = DBResources.new()
$battles = {}
# $log = Logger.new('./logs/server.log')

class Connection < EM::Connection  
  @player = nil
  @latency = 0
  def get_player()
    @player
  end

  def get_latency()
    @latency
  end

  def post_init
    # $log.info("New connection from #{get_peername[2,6].unpack("nC4")}")
  end

  def make_response (response, action)
    response[:timestamp] = Time.now.to_f
    response[:action] = action
    response[:latency] = @latency.to_i
    send_data("__JSON__START__#{response.to_json}__JSON__END__")
    # $log.debug("Send message: #{response}")
  end

  def receive_data(message)
    str_start, str_end = message.index('__JSON__START__'), message.index('__JSON__END__')
    if str_start and str_end
      json = message[ str_start + 15 .. str_end - 1 ]
      # $log.debug("Receive message: #{json}")
      data = JSON.parse(json,:symbolize_names => true)
      action = data[:action]
      case action.to_sym
      when :request_player
        @player = Player.new(data[:login_data][:rand_id])
        make_response({:uid => @player.get_id(), :game_data => @player.get_game_data()}, action)
        # $connections[@player.get_id()] = self

      when :request_new_battle
        # Тут нужна проверка, может ли игрок в данное время нападать на это AI
        battle_director = BattleDirector.new()
        battle_director.set_opponent(self)
        battle_director.enable_ai(data[:ai_uid]) if data[:is_ai_battle]
        $battles[battle_director.get_uid()] = battle_director
        response = {:battle_ready => true, :battle_uid => battle_director.get_uid()}
        response[:ai_uid] = data[:ai_uid] if data[:is_ai_battle]
        make_response(response, action)

      when :request_battle_start
        $battles[data[:battle_uid]].set_opponent_ready(data[:player_id])
      when :spawn_unit

      when :ping
        @latency = Time.now.to_f * 1000.0 - data[:time]
      end
    end
  end
end

EventMachine::run do
  host = '127.0.0.1'
  port = 3005
  EventMachine::start_server host, port, Connection
  
  EM.tick_loop do
    $battles.each do |battle_uid, battle|
      battle.update_opponents() if battle.is_started?
    end    
  end

  puts "Started MageServer on #{host}:#{port}..."
  # $log.info("Started MageServer on #{host}:#{port}...")
end
