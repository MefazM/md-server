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
require_relative 'units_factory.rb'

require_relative 'mage_logger.rb'
require_relative 'deferred_tasks.rb'
require_relative 'responders.rb'

require_relative 'settings.rb'

require 'instrumental_agent'
I = Instrumental::Agent.new('a9bd7ba1905e5eadd0d03efe7505368f')

$input_package_count = 0
$output_package_count = 0

$output_package_size_max = 0
$output_package_size_pre_sec = 0

$input_package_size_max = 0
$input_package_size_pre_sec = 0

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
    $output_package_count += 1
    send_data("__JSON__START__#{response.to_json}__JSON__END__")

    str_size = bytesize("__JSON__START__#{response.to_json}__JSON__END__")

    str_size = str_size / 1000

    $output_package_size_max = str_size if str_size > $output_package_size_max
    $output_package_size_pre_sec += str_size
  end

  def receive_data(message)
    $input_package_count += 1

    str_size = bytesize(message)
    str_size = str_size / 1000

    $input_package_size_max = str_size if str_size > $input_package_size_max
    $input_package_size_pre_sec += str_size

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
        players = PlayerFactory.appropriate_players_for_battle(@player_id)
        ai = [{:id => 13123, :title => 'someshit'}, {:id => 334, :title => '111min'}]
        send_message(
          Respond.as_battle_map(players, ai),
          action
        )
      when :request_spawn_unit

        BattleDirectorFactory.instance.spawn_unit(
          @battle_director_uid,
          data[:unit_uid],
          @player_id
        )
      when :request_production_task

        case data[:type]
        when 1 #unit
          # resource = DBResources.get_unit(data[:package])
          # DeferredTasks.instance.add_task_with_sequence(@player_id, data[:package], 1, 10, 44)
          UnitsFactory.instance.add_production_task(@player_id, data[:package])

        when 2 #building
          BuildingsFactory.instance.build_or_update(@player_id, data[:package])
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

  EventMachine::PeriodicTimer.new(0.5) do
    UnitsFactory.instance.update_production_tasks()
  end

  last_em_ping = Time.now.to_f
  EM::PeriodicTimer.new(1) do
    current_time = Time.now.to_f
    latency = current_time - last_em_ping
    I.gauge('em.latency', latency)
    last_em_ping = current_time

    I.gauge('em.d_input_package_count', $input_package_count)
    $input_package_count = 0

    I.gauge('em.d_output_package_count', $output_package_count)
    $output_package_count = 0


    I.gauge('em.output_package_size_max', $output_package_size_max)
    $output_package_size_max = 0

    I.gauge('em.output_package_size_pre_sec', $output_package_size_pre_sec)
    $output_package_size_pre_sec = 0

    if $output_package_count > 0
      I.gauge('em.output_package_size_pre_avg', $output_package_size_pre_sec / $output_package_count)
    end

    I.gauge('em.input_package_size_max', $input_package_size_max)
    $input_package_size_max = 0

    I.gauge('em.input_package_size_pre_sec', $input_package_size_pre_sec)
    $input_package_size_pre_sec = 0

    if $input_package_count > 0
      I.gauge('em.input_package_size_pre_avg', $input_package_size_pre_sec / $input_package_count)
    end

  end
end
