require "securerandom"
require 'pry'
require_relative 'ai_player.rb'
require_relative 'defines.rb'
require_relative 'battle_unit.rb'
require_relative 'battle_building.rb'

class BattleDirector

  def initialize()
    @opponents = {}

    @status = BattleStatuses::PENDING
    @uid = SecureRandom.hex(5)

    @opponents_indexes = {}
    @iteration_time = Time.now.to_f
    @ping_time = Time.now.to_f
    @default_unit_spawn_time = 0

    MageLogger.instance.info "New BattleDirector initialize... UID = #{@uid}"
  end

  def set_opponent(connection, player)
    player_id = player.get_id()

    @opponents[player_id] = {
      :connection => connection,
      :player => player,
      :is_ready => false,
      :units_pool => {},
      :main_building => nil
    }
    MageLogger.instance.info "BattleDirector (UID=#{@uid}) added opponent. ID = #{player_id}"
    # Если достаточное количество игроков чтобы начать бой
    create_battle_at_clients() if @opponents.count == 2
  end

  def enable_ai(ai_uid)
    MageLogger.instance.info "BattleDirector (UID=#{@uid}) enable AI. UID = #{ai_uid} "

    @opponents[ai_uid] = {
      :connection => nil,
      :player => AiPlayer.new(),
      :is_ready => true,
      :units_pool => {},
      :main_building => nil
    }
    create_battle_at_clients()
  end

  def set_opponent_ready(player_id)
    MageLogger.instance.info "BattleDirector (UID=#{@uid}) opponent ID = #{player_id} is ready to battle."
    @opponents[player_id][:is_ready] = true
    if (ready_to_start?)
      start()
    end
  end

  def is_started?()
    @status == BattleStatuses::IN_PROGRESS
  end

  def get_uid()
    @uid
  end

  def update_opponents(current_time)
    #
    # World update
    #
    iteration_delta = current_time - @iteration_time
    if (iteration_delta > Timings::ITERATION_TIME)
      @iteration_time = current_time
      update_opponent(iteration_delta)
    end
    # /World update

    #
    # Ping update
    #
    if current_time - @ping_time > Timings::PING_TIME
      @ping_time = current_time

      broadcast_response({:time => current_time}, 'ping')
    end
    # /Ping update

    #
    # Default unit spawn
    if current_time - @default_unit_spawn_time > Timings::DEFAULT_UNITS_SPAWN_TIME
      @default_unit_spawn_time = current_time

      @opponents.each do |player_id, opponent|
        unit_package = 'crusader'

        spawn_data = add_unit_to_pool(opponent, unit_package)
        spawn_data[:owner_id] = player_id
        broadcast_response(spawn_data, 'spawn_unit')
      end
    end
    # /Default unit spawn
  end

  def spawn_unit (unit_uid, player_id)
    spawn_data = add_unit_to_pool(@opponents[player_id], unit_uid)
    spawn_data[:owner_id] = player_id

    broadcast_response(spawn_data, 'spawn_unit')
  end

private

  def broadcast_response(data, action)
    @opponents.each_value { |opponent|
      opponent[:connection].send_message(data, action) unless opponent[:connection].nil?
    }
  end

  def add_unit_to_pool(opponent, unit_package)
    unit = BattleUnit.new(unit_package)
    uid = unit.get_uid()
    opponent[:units_pool][uid] = unit

    return unit.to_hash(true)
  end

  def update_opponent(iteration_delta)
    @opponents.each do |player_id, player|

      opponent_uid = @opponents_indexes[player_id]
      opponent = @opponents[opponent_uid]

      response = {}

      player[:units_pool].each do |uid, unit|

        response[uid] = unit.update(opponent, iteration_delta)

        player[:units_pool].delete(uid) if unit.dead?
      end

      main_building = player[:main_building]
      main_building.process_deffered_damage(iteration_delta)
      response[main_building.get_uid()] = main_building.to_hash

      if main_building.dead?

        finish_battle(player_id)
      end

      broadcast_response({:units_data => response, :player_id => player_id}, 'sync_client')
    end
  end

  def start()
    MageLogger.instance.info "BattleDirector (UID=#{@uid}) is started!"

    @status = BattleStatuses::IN_PROGRESS

    broadcast_response({:message => 'Let the battle begin!'}, 'start_battle')

    @iteration_time = Time.now.to_f
    @ping_time = Time.now.to_f
    @default_unit_spawn_time = 0
  end

  def ready_to_start?()
    @opponents.each_value { |opponent|
      return opponent[:is_ready] unless opponent[:is_ready]
    }
    return true
  end

  # Оба игрока согласны на бой. Надо инициализировать бой на их устройствах.
  # Также надо передать информацию о доступных юнитах
  def create_battle_at_clients()
    MageLogger.instance.info "BattleDirector (UID=#{@uid}) has two opponents. Initialize battle on clients."

    _opponents_indexes = []
    # Надо собрать данные о обоих сновных постойках игрока
    opponents_main_buildings = []

    @opponents.each do |player_id, opponent|
      player_building = BattleBuilding.new( 'building_1', 0.1 )
      opponent[:main_building] = player_building

      player_building_data = player_building.to_hash()
      player_building_data[:owner_id] = player_id

      opponents_main_buildings << player_building_data
    end
    #
    @opponents.each do |player_id, opponent|

      _opponents_indexes << player_id

      player_units = opponent[:player].get_units_data_for_battle()

      opponent[:connection].send_message({
        :battle_uid => @uid,
        :units => player_units,
        :buildings => opponents_main_buildings,
      }, 'request_new_battle') unless opponent[:connection].nil?
    end
    # Хак, чтобы получить uid игрока, по uid'у его оппонента.
    @opponents_indexes[_opponents_indexes[0]] = _opponents_indexes[1]
    @opponents_indexes[_opponents_indexes[1]] = _opponents_indexes[0]
  end

  def finish_battle(loser_id)
    MageLogger.instance.info "BattleDirector (UID=#{@uid}). Battle finished, player (#{loser_id} - lose."

    @status = BattleStatuses::FINISHED

    broadcast_response({:loser_id => loser_id}, 'finish_battle')
  end
end
