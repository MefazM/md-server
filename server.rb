#!/usr/bin/env ruby
require 'pry'
require 'rubygems'
require 'eventmachine'
require 'json'
require 'singleton'

require_relative 'mage_logger.rb'
require_relative 'player.rb'
require_relative 'battle_director_factory.rb'
require_relative 'db_connection.rb'
require_relative 'player_factory.rb'
require_relative 'buildings_factory.rb'
require_relative 'units_factory.rb'
require_relative 'settings.rb'
require_relative 'networking.rb'
require_relative 'game_data.rb'

class Connection < EM::Connection

  include NETWORKING

  def post_init
    @latency = 0
  end

  def unbind
    MageLogger.instance.info "Connection closed for player ID = #{@player_id}."
  end

  def receive_data(message)
    str_start, str_end = message.index('__JSON__START__'), message.index('__JSON__END__')
    if str_start and str_end
      json = message[ str_start + 15 .. str_end - 1 ]
      action, *data = JSON.parse(json,:symbolize_names => true)
      # puts("ACTION:#{action}, DATA:#{data.inspect}")
      case action
      when RECEIVE_PLAYER_ACTION
        @player_id = PlayerFactory.instance.find_or_create(data[0], self)
        PlayerFactory.instance.send_game_data(@player_id)
      when RECEIVE_NEW_BATTLE_ACTION
        # Cancel battle invite if
        # - opponen already in battle
        # - by timeout
        # - if opponen don't accept battle

        BattleDirectorFactory.instance.invite(@player_id, data[0])

        # opponent = PlayerFactory.instance.get_player_by_id(@player_id)
        # if opponent.frozen?

        # else

        # end

        # @battle_director = BattleDirectorFactory.instance.create()

        # @battle_director.set_opponent(self, opponent)
        # # Если это бой с AI - подтверждение не требуется, сразу инициируем создание боя на клиенте.
        # # и ждем запрос для начала боя.
        # # Тутже надо добавить список ресурсов для прелоада
        # # data[0] - opponent or AI uid.
        # opponent_id = data[0]
        # # Is ai battle?
        # if data[1] == true
        #   @battle_director.enable_ai(opponent_id)
        # else
        #   # Send invite to opponent
        #   connection = PlayerFactory.instance.connection(opponent_id)
        #   unless connection.nil?
        #     connection.send_invite_to_battle(@battle_director.uid, @player_id)
        #   end
        # end

      when RECEIVE_RESPONSE_BATTLE_INVITE_ACTION
        MageLogger.instance.info "Player ID = #{@player_id}, response to battle invitation. UID = #{data[0]}."
        # data[0] - uid
        # data[1] - is accepted
        BattleDirectorFactory.instance.opponent_response_to_invitation(@player_id, data[0], data[1])

        # @battle_director = BattleDirectorFactory.instance.get(data[0])
        # @battle_director.set_opponent(
        #   self, PlayerFactory.instance.get_player_by_id(@player_id)
        # )

      when RECEIVE_BATTLE_START_ACTION
        @battle_director.set_opponent_ready(@player_id)
      when RECEIVE_LOBBY_DATA_ACTION
        # Collect data for user battle lobby
        appropriate_players = PlayerFactory.instance.appropriate_players_for_battle(@player_id)
        appropriate_ai = [[13123, 'Boy_1'], [334, 'Boy_2']]

        connection = PlayerFactory.instance.connection(@player_id)
        unless connection.nil?
          connection.send_lobby_data(appropriate_players, appropriate_ai)
        end
      when RECEIVE_SPAWN_UNIT_ACTION
        @battle_director.spawn_unit(data[0], @player_id)

      when RECEIVE_UNIT_PRODUCTION_TASK_ACTION

        PlayerFactory.instance.try_to_train_unit(@player_id, data[0].to_sym)

      when RECEIVE_BUILDING_PRODUCTION_TASK_ACTION

        PlayerFactory.instance.try_update_building(@player_id, data[0])

      when RECEIVE_SPELL_CAST_ACTION

        @battle_director.cast_spell(@player_id, data[0], data[1])

      when RECEIVE_DO_HARVESTING_ACTION

        PlayerFactory.instance.harvest_coins(@player_id)

      when RECEIVE_PING_ACTION

        @latency = (Time.now.to_f - data[0]).round(3)

      when RECEIVE_REQUEST_CURRENT_MINE_AMOUNT

        PlayerFactory.instance.send_current_mine_amount(@player_id)

      end
    end
  end
end

EventMachine::run do
  host = Settings::SERVER_HOST
  port = Settings::SERVER_PORT
  Signal.trap("INT")  { EventMachine.stop }
  Signal.trap("TERM") { EventMachine.stop }
  MageLogger.instance.info "Starting MageServer on #{host}:#{port}..."
  DBConnection.connect(Settings::MYSQL_HOST, Settings::MYSQL_USER_NAME, Settings::MYSQL_DB_NAME, Settings::MYSQL_PASSWORD)
  EventMachine::start_server host, port, Connection
  # This timer update battles.
  EventMachine::PeriodicTimer.new(0.1) do
    BattleDirectorFactory.instance.update(Time.now.to_f)
  end
  # This timer update production queue and send ping actions(is alive?)
  EventMachine::PeriodicTimer.new(0.5) do
    current_time = Time.now.to_f
    UnitsFactory.instance.update_production_tasks(current_time)
    BuildingsFactory.instance.update_production_tasks(current_time)
    PlayerFactory.instance.brodcast_ping(current_time)
  end
  # Process notifications about gold mine storage filling.
  EventMachine::PeriodicTimer.new(2) do
    current_time = Time.now.to_i
    PlayerFactory.instance.brodcast_mine_capacity(current_time)
    BattleDirectorFactory.instance.process_invitation_queue(current_time)
  end
end
