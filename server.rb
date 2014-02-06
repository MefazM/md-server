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

  attr_accessor :battle_director, :player

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
      MageLogger.instance.info "RECEIVE: #{json}"
      case action
      when RECEIVE_PLAYER_ACTION
        @player_id = PlayerFactory.instance.find_or_create(data[0], self)

        send_game_data({
          :uid => @player.id,
          :player_data => @player.game_data(),
          :game_data => GameData.instance.collected_data,
          :server_version => Settings::SERVER_VERSION
        })

      when RECEIVE_NEW_BATTLE_ACTION
        # Cancel battle invite if
        # - opponen already in battle
        # - by timeout
        # - if opponen don't accept battle
        # Is ai battle?
        if data[1] == true
          BattleDirectorFactory.instance.create_ai_battle(@player_id, data[0])
        else
          BattleDirectorFactory.instance.invite(@player_id, data[0])
        end

      when RECEIVE_RESPONSE_BATTLE_INVITE_ACTION
        MageLogger.instance.info "Player ID = #{@player_id}, response to battle invitation. UID = #{data[0]}."
        # data[0] - uid
        # data[1] - is accepted
        BattleDirectorFactory.instance.opponent_response_to_invitation(@player_id, data[0], data[1])

      when RECEIVE_BATTLE_START_ACTION

        @battle_director.set_opponent_ready(@player_id)

      when RECEIVE_LOBBY_DATA_ACTION
        # Collect data for user battle lobby
        appropriate_players = PlayerFactory.instance.appropriate_players_for_battle(@player_id)
        appropriate_ai = [[13123, 'Boy_1'], [334, 'Boy_2']]

        send_lobby_data(appropriate_players, appropriate_ai)

      when RECEIVE_SPAWN_UNIT_ACTION
        @battle_director.spawn_unit(data[0], @player_id)

      when RECEIVE_UNIT_PRODUCTION_TASK_ACTION

        unit_uid = data[0].to_sym
        price = UnitsFactory.instance.price(unit_uid)
        if @player.make_payment(price)
          task_data = UnitsFactory.instance.add_production_task(@player.id, unit_uid)
          # Responce to client
          send_unit_queue(*task_data)
          send_coins_storage_capacity(@player.coins_in_storage, @player.storage_capacity)
        end

      when RECEIVE_BUILDING_PRODUCTION_TASK_ACTION

        building_uid = data[0]
        # if player already construct this building, current_level > 0
        target_level = @player.building_level(building_uid) + 1
        price = BuildingsFactory.instance.price(building_uid, target_level)
        if @player.make_payment(price)
          task_data = BuildingsFactory.instance.add_production_task(@player.id, building_uid, target_level)
          # Notify client about task start
          # Convert to client ms
          production_time_in_ms = task_data[:production_time] * 1000
          # Send new started task data
          send_sync_building_state(building_uid, target_level, false, production_time_in_ms)
          # Send new coins amount
          send_coins_storage_capacity(@player.coins_in_storage, @player.storage_capacity)
        end

      when RECEIVE_SPELL_CAST_ACTION

        @battle_director.cast_spell(@player_id, data[0], data[1])

      when RECEIVE_DO_HARVESTING_ACTION

        unless @player.storage_full?
          @player.harvest
          send_coins_storage_capacity(@player.coins_in_storage, @player.storage_capacity)
        end

      when RECEIVE_PING_ACTION

        @latency = (Time.now.to_f - data[0]).round(3)

      when RECEIVE_REQUEST_CURRENT_MINE_AMOUNT

        amount = @player.mine_amount(Time.now.to_i)
        capacity = @player.harvester_capacity
        gain = @player.coins_gain

        send_current_mine_amount(amount, capacity, gain)

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
