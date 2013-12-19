#!/usr/bin/env ruby
require 'pry'
require 'rubygems'
require 'eventmachine'
require 'json'

require_relative 'battle_director_factory.rb'
require_relative 'db_connection.rb'
require_relative 'player_factory.rb'
require_relative 'buildings_factory.rb'
require_relative 'units_factory.rb'
require_relative 'mage_logger.rb'
require_relative 'deferred_tasks.rb'
require_relative 'settings.rb'
require_relative 'networking.rb'
require_relative 'game_data.rb'

class Connection < EM::Connection

  include NETWORKING

  def post_init
    @latency = 0
  end

  def receive_data(message)
    str_start, str_end = message.index('__JSON__START__'), message.index('__JSON__END__')
    if str_start and str_end
      json = message[ str_start + 15 .. str_end - 1 ]
      action, *data = JSON.parse(json,:symbolize_names => true)
      # puts("ACTION:#{action}, DATA:#{data.inspect}")
      case action
      when RECEIVE_PLAYER_ACTION
        @player_id = PlayerFactory.find_or_create(data[0], self)
        PlayerFactory.send_game_data(@player_id)
      when RECEIVE_NEW_BATTLE_ACTION
        # Тут нужна проверка, может ли игрок в данное время нападать на это AI или игрока.
        # возможно добавлять battle_director только после согласия обоих игроков на бой?
        @battle_director = BattleDirectorFactory.instance.create()
        @battle_director.set_opponent(self, PlayerFactory.get_player_by_id(@player_id))
        # Если это бой с AI - подтверждение не требуется, сразу инициируем создание боя на клиенте.
        # и ждем запрос для начала боя.
        # Тутже надо добавить список ресурсов для прелоада
        # data[0] - opponent or AI uid.
        opponent_id = data[0]
        # Is ai battle?
        if data[1] == true
          @battle_director.enable_ai(opponent_id)
        else
          # Send invite to opponent
          connection = PlayerFactory.connection(opponent_id)
          unless connection.nil?
            connection.send_invite_to_battle(@battle_director.uid, @player_id)
          end
        end

      when RECEIVE_ACCEPT_BATTLE_ACTION
        MageLogger.instance.info "Player ID = #{@player_id}, accepted battle UID = #{data[0]}."
        @battle_director = BattleDirectorFactory.instance.get(data[0])
        @battle_director.set_opponent(
          self, PlayerFactory.get_player_by_id(@player_id)
        )

      when RECEIVE_BATTLE_START_ACTION
        @battle_director.set_opponent_ready(@player_id)
      when RECEIVE_LOBBY_DATA_ACTION
        # Collect data for user battle lobby
        appropriate_players = PlayerFactory.appropriate_players_for_battle(@player_id)
        appropriate_ai = [[13123, 'someshit'], [334, '111min']]

        connection = PlayerFactory.connection(@player_id)
        unless connection.nil?
          connection.send_lobby_data(appropriate_players, appropriate_ai)
        end
      when RECEIVE_SPAWN_UNIT_ACTION
        @battle_director.spawn_unit(data[0], @player_id)

      when RECEIVE_UNIT_PRODUCTION_TASK_ACTION

        UnitsFactory.instance.add_production_task(@player_id, data[0])

      when RECEIVE_BUILDING_PRODUCTION_TASK_ACTION

        BuildingsFactory.instance.build_or_update(@player_id, data[0])

      when RECEIVE_SPELL_CAST_ACTION
        #
        @battle_director.cast_spell(@player_id, data[0], data[1])
      when RECEIVE_PING_ACTION

        @latency = Time.now.to_f - data[0]
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

  EventMachine::PeriodicTimer.new(0.1) do

    current_time = Time.now.to_f

    BattleDirectorFactory.instance.update(current_time)
    DeferredTasks.instance.process_all(current_time)
  end

  EventMachine::PeriodicTimer.new(0.5) do
    UnitsFactory.instance.update_production_tasks()
  end
end
