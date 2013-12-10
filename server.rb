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
require_relative 'responders.rb'

require_relative 'settings.rb'

require_relative 'network_responder.rb'




class Connection < EM::Connection

  include NETWORK_SEND_DATA

  def get_latency()
    @latency
  end

  def post_init
    @latency = 0
  end



  def receive_data(message)
    str_start, str_end = message.index('__JSON__START__'), message.index('__JSON__END__')
    if str_start and str_end
      json = message[ str_start + 15 .. str_end - 1 ]

      data = JSON.parse(json,:symbolize_names => true)
      action = data[:action]

      case action.to_sym
      when :request_player
        @player_id = PlayerFactory.find_or_create(data[:login_data], self)
        PlayerFactory.send_game_data(@player_id)
      when :request_new_battle
        # Тут нужна проверка, может ли игрок в данное время нападать на это AI или игрока.
        # возможно добавлять battle_director только после согласия обоих игроков на бой?
        @battle_director = BattleDirectorFactory.instance.create()

        @battle_director.set_opponent(self, PlayerFactory.get_player_by_id(@player_id))

        # Если это бой с AI - подтверждение не требуется, сразу инициируем создание боя на клиенте.
        # и ждем запрос для начала боя.
        # Тутже надо добавить список ресурсов для прелоада
        # data[:id] - opponent or AI uid.
        opponent_id = data[:id]

        if data[:is_ai_battle]
          @battle_director.enable_ai(opponent_id)
        else
          # Send invite to opponent
          connection = PlayerFactory.connection(opponent_id)
          connection.send_invite_to_battle(@battle_director.uid, @player_id)
        end

      when :accept_battle
        MageLogger.instance.info "Player ID = #{@player_id}, accepted battle UID = #{data[:battle_uid]}."
        @battle_director = BattleDirectorFactory.instance.get(data[:battle_uid])
        @battle_director.set_opponent(
          self,
          PlayerFactory.get_player_by_id(@player_id) # maybe remove this? and get player
                                                     # after intit?
        )

      when :request_battle_start
        @battle_director.set_opponent_ready(@player_id)
      when :request_battle_map_data
        appropriate_players = PlayerFactory.appropriate_players_for_battle(@player_id)
        appropriate_ai = [[13123, 'someshit'], [334, '111min']]

        connection = PlayerFactory.connection(opponent_id)
        connection.send_lobby_data(appropriate_players, appropriate_ai)
      when :request_spawn_unit
        @battle_director.spawn_unit(data[:unit_uid], @player_id)
      when :request_production_task
        case data[:type]
        when 1 #unit
          # resource = DBResources.get_unit(data[:package])
          # DeferredTasks.instance.add_task_with_sequence(@player_id, data[:package], 1, 10, 44)
          UnitsFactory.instance.add_production_task(@player_id, data[:package])

        when 2 #building
          BuildingsFactory.instance.build_or_update(@player_id, data[:package])
        end

      when :request_spell_cast
        @battle_director.cast_spell(
          @player_id,
          data[:target_area],
          data[:spell_uid]
        )
      when :ping

        @latency = Time.now.to_f - data[:time]
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
  # DBResources.load_resources

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
