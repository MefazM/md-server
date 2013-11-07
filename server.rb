#!/usr/bin/env ruby
require 'pry'
require 'rubygems'
require 'eventmachine'
require 'json'

require_relative 'battle_director_factory.rb'
require_relative 'db_connection.rb'
require_relative 'db_resources.rb'
require_relative 'player_factory.rb'
require_relative 'buildings_factory.rb'
require_relative 'mage_logger.rb'
require_relative 'deferred_tasks.rb'

require_relative 'settings.rb'


class Connection < EM::Connection

  def get_latency()
    @latency
  end

  def post_init
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
        @player_id = PlayerFactory.find_or_create(data[:login_data], self)
        PlayerFactory.send_game_data(@player_id)
      when :request_new_battle
        # Тут нужна проверка, может ли игрок в данное время нападать на это AI или игрока.
        # возможно добавлять battle_director только после согласия обоих игроков на бой?
        @battle_director_uid = BattleDirectorFactory.instance.create()

        BattleDirectorFactory.instance.set_opponent(
          @battle_director_uid,
          self,
          PlayerFactory.get_player_by_id(@player_id)
        )
        # Если это бой с AI - подтверждение не требуется, сразу инициируем создание боя на клиенте.
        # и ждем запрос для начала боя.
        # Тутже надо добавить список ресурсов для прелоада
        if data[:is_ai_battle]
          BattleDirectorFactory.instance.enable_ai(
            @battle_director_uid,
            data[:id]
          )
        else
          # Send invite to opponent
          opponent = PlayerFactory.send_message(
            data[:id],
            { :battle_uid => @battle_director_uid,
              :invitation_from => @player_id },
            'invite_to_battle'
          )
        end

      when :accept_battle
        MageLogger.instance.info "Player ID = #{@player_id}, accepted battle UID = #{data[:battle_uid]}."
        @battle_director_uid = data[:battle_uid]

        BattleDirectorFactory.instance.set_opponent(
          @battle_director_uid,
          self,
          PlayerFactory.get_player_by_id(@player_id)
        )
      when :request_battle_start
        BattleDirectorFactory.instance.set_opponent_ready(
          @battle_director_uid,
          @player_id
        )
      when :request_battle_map_data
        response = {}
        response[:players] = {}#DataCollector.get_appropriate_players(@player_id)
        response[:ai] = [{:id => 13123, :title => 'someshit'}, {:id => 334, :title => '111min'}]

        send_message(response, action)

      when :request_spawn_unit

        BattleDirectorFactory.instance.spawn_unit(
          @battle_director_uid,
          data[:unit_uid],
          @player_id
        )
      when :request_production_task

        case data[:task_info][:type]
        when 1 #unit
          resource = DBResources.get_unit(data[:task_info][:uid])
          DeferredTasks.instance.add_task_with_sequence(@player_id, data[:task_info][:uid], 1, 10, 44)

        when 2 #building
          BuildingsFactory.instance.build_or_update(@player_id, data[:task_info][:package])
        end
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
  DBResources.load_resources

  EventMachine::start_server host, port, Connection

  EventMachine::PeriodicTimer.new(0.01) do

    current_time = Time.now.to_f

    BattleDirectorFactory.instance.update(current_time)
    DeferredTasks.instance.process_all(current_time)

  end
end
