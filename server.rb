#!/usr/bin/env ruby
require 'pry'
require 'rubygems'
require 'eventmachine'
require 'json'
require 'logger'

require_relative 'battle_director.rb'
require_relative 'db_connection.rb'
require_relative 'db_resources.rb'
require_relative 'player_factory.rb'
require_relative 'mage_logger.rb'

$battles = {}

class Connection < EM::Connection
  def get_player()
    @player
  end

  def set_player(player)
    @player = player
  end

  def get_latency()
    @latency
  end

  def post_init
    @player = nil
    @battle_director = nil
    @latency = 0
  end

  def send_message(response, action)
    response[:action] = action
    response[:latency] = (@latency * 1000.0).to_i
    send_data("__JSON__START__#{response.to_json}__JSON__END__")
  end

  def receive_data(message)
    str_start, str_end = message.index('__JSON__START__'), message.index('__JSON__END__')
    if str_start and str_end
      json = message[ str_start + 15 .. str_end - 1 ]

      data = JSON.parse(json,:symbolize_names => true)
      action = data[:action]

      case action.to_sym
      when :request_player

        PlayerFactory.find_or_create(data[:login_data], self)
        send_message({:uid => @player.get_id(), :game_data => @player.get_game_data()}, action)

      when :request_new_battle
        # Тут нужна проверка, может ли игрок в данное время нападать на это AI или игрока.
        battle_director = BattleDirector.new()
        battle_director.set_opponent(self)
        # возможно добавлять battle_director только после согласия обоих игроков на бой?
        $battles[battle_director.get_uid()] = battle_director

        @battle_director = battle_director
        # Если это бой с AI - подтверждение не требуется, сразу инициируем создание боя на клиенте.
        # и ждем запрос для начала боя.
        # Тутже надо добавить список ресурсов для прелоада
        if data[:is_ai_battle]
          battle_director.enable_ai(data[:id])

        else
          opponent = PlayerFactory.get_connection(data[:id])

          opponent.send_message({
            :battle_uid => battle_director.get_uid(),
            :invitation_from => @player.get_id()},
            'invite_to_battle'
          )
        end

      when :accept_battle
        MageLogger.instance.info "Player ID = #{@player.get_id()}, accepted battle UID = #{data[:battle_uid]}."
        @battle_director = $battles[data[:battle_uid]]
        @battle_director.set_opponent(self)

      when :request_battle_start

        @battle_director.set_opponent_ready(@player.get_id())

      when :request_battle_map_data
        response = {}

        response[:players] = PlayerFactory.get_appropriate_players(@player.get_id())
        response[:ai] = [{:id => 13123, :title => 'someshit'}, {:id => 334, :title => '111min'}]

        send_message(response, action)

      when :request_spawn_unit

        @battle_director.spawn_unit(data[:unit_uid], @player.get_id())

      when :ping

        @latency = Time.now.to_f - data[:time]

      end
    end
  end
end

EventMachine::run do
  host = '127.0.0.1'
  port = 3005

  MageLogger.instance.info "Starting MageServer on #{host}:#{port}..."

  DBConnection.connect
  DBResources.load_resources

  EventMachine::start_server host, port, Connection

  EM.tick_loop do
    $battles.each do |battle_uid, battle|
      battle.update_opponents() if battle.is_started?
    end
  end
end
