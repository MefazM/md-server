require "securerandom"
require 'pry'
require_relative 'ai_player.rb'
require_relative 'defines.rb'
require_relative 'battle_unit.rb'


class BattleDirector

  def initialize()
    @opponents = {}

    @status = BattleStatuses::PENDING
    @uid = SecureRandom.hex(5)

    @opponents_indexes = []
    @iteration_time = get_timer()
    @ping_time = get_timer()
    @default_unit_spawn_time = 0

    MageLogger.instance.info "New BattleDirector initialize... UID = #{@uid}"
  end

  def set_opponent(connection)
    player_id = connection.get_player().get_id()
    @opponents_indexes << player_id
    
    @opponents[player_id] = { 
      :player => connection.get_player(),
      :connection => connection,
      :is_ready => false, 
      :units_pool => {}
    }

    MageLogger.instance.info "BattleDirector (UID=#{@uid}) added opponent. ID = #{player_id}"

    # Если достаточное количество игроков чтобы начать бой
    create_battle_at_clients() if @opponents.count == 2
  end

  def enable_ai(ai_uid)
    MageLogger.instance.info "BattleDirector (UID=#{@uid}) enable AI. UID = #{ai_uid} "
    
    @opponents_indexes << ai_uid
    
    @opponents[ai_uid] = {
      :player => AiPlayer.new(),
      :connection => nil,
      :is_ready => true, 
      :units_pool => {}, 
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

  def update_opponents()
    current_time = get_timer()
    #
    # World update
    #
    iteration_delta = current_time - @iteration_time
    if (iteration_delta > Timings::ITERATION_TIME)
      @iteration_time = current_time

      attack_phase(iteration_delta)
      deffered_attack_phase(iteration_delta)

      @opponents.each do |player_id, opponent|
        response = {}
        opponent[:units_pool].each do |uid, unit|

          if unit.is_dead?

            unit.set_status(UnitStatuses::DIE)
            opponent[:units_pool].delete(uid)
          elsif unit.respond_status? UnitStatuses::MOVE

            unit.move(iteration_delta)
          end

          response[uid] = unit.to_hash
        end
        broadcast_response({:units_data => response, :player_id => player_id}, 'sync_client')
      end
    end
    # /World update

    # 
    # Ping update
    #
    if current_time - @ping_time > Timings::PING_TIME
      @ping_time = current_time
      @opponents.each do |player_id, opponent|
        opponent[:connection].send_message({:time => current_time}, 'ping') unless opponent[:connection].nil?
      end
    end
    # /Ping update

    # 
    # Default unit spawn
    if current_time - @default_unit_spawn_time > Timings::DEFAULT_UNITS_SPAWN_TIME
      @default_unit_spawn_time = current_time
      @opponents.each do |player_id, opponent|
        unit_package = opponent[:player].get_default_unit_package()
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

  def get_timer()
    Time.now.to_f
  end

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

  def deffered_attack_phase(iteration_delta)
    @opponents.each do |player_id, opponent|
      opponent[:units_pool].each do |uid, unit|
        unit.process_deffered_damage(iteration_delta)
      end
    end
  end

  def has_target(opponent, position, attack_distantion)
    opponent[:units_pool].each do |uid, opponent_unit|
      distantion = opponent_unit.get_position() + position
      if distantion > 1.0 - attack_distantion and attack_distantion < 1.0
        return true
      end
    end
    return false
  end

  def get_target(opponent, position, attack_distantion)
    opponent[:units_pool].each do |uid, opponent_unit|
      distantion = opponent_unit.get_position() + position and attack_distantion < 1.0
      if distantion > 1.0 - attack_distantion
        return opponent_unit
      end
    end
    return nil
  end

  def make_attack(opponent, unit, iteration_delta)
    case unit.get_status()
    when UnitStatuses::START_ATTACK
      if unit.decrease_attack_timer(iteration_delta) < 0
        case unit.get_current_attack_type()
        when :melee_attack
          opponent_unit = get_target(opponent, unit.get_position(), unit.get_attack_option(:melee_attack_range))
          opponent_unit.decrease_health_points(unit.get_melee_attack_power()) unless opponent_unit.nil?
          unit.set_status(UnitStatuses::DEFAULT)
        when :range_attack
          opponent_unit = get_target(opponent, unit.get_position(), unit.get_attack_option(:range_attack_range))
          unless opponent_unit.nil?
            opponent_unit.add_deffered_damage(unit.get_range_attack_power(), unit.get_position())
            unit.set_current_attacked_unit(opponent_unit.get_uid())
          end
          unit.set_status(UnitStatuses::FINISH_ATTACK)
        end
      end
    when UnitStatuses::FINISH_ATTACK
      unit.set_status(UnitStatuses::DEFAULT)
      unit.set_current_attacked_unit(nil)

    when UnitStatuses::MOVE, UnitStatuses::DEFAULT
      if unit.has_attack?(:melee_attack) and has_target(opponent, unit.get_position(), unit.get_attack_option(:melee_attack_range))
        unit.set_status(UnitStatuses::START_ATTACK)

        unit.set_current_attack_type(:melee_attack)
        unit.set_attack_period_time(:melee_attack_speed)
      elsif unit.has_attack?(:range_attack) and has_target(opponent, unit.get_position(), unit.get_attack_option(:range_attack_range))
        unit.set_status(UnitStatuses::START_ATTACK)
        
        unit.set_current_attack_type(:range_attack)
        unit.set_attack_period_time(:range_attack_speed)
      else

        unit.set_status(UnitStatuses::MOVE)
      end
    end
  end

  def attack_phase(iteration_delta)
    opponent_1 = @opponents[@opponents_indexes[0]]
    opponent_2 = @opponents[@opponents_indexes[1]]

    opponent_1[:units_pool].each do |uid, unit|
      make_attack(opponent_2, unit, iteration_delta)
    end

    opponent_2[:units_pool].each do |uid, unit|
      make_attack(opponent_1, unit, iteration_delta)
    end  
  end
 
  def start()
    MageLogger.instance.info "BattleDirector (UID=#{@uid}) is started!"

    @status = BattleStatuses::IN_PROGRESS
    
    broadcast_response({:message => 'Let the battle begin!'}, 'start_battle')

    @iteration_time = get_timer()
    @ping_time = get_timer()
    @default_unit_spawn_time = 0
  end

  def ready_to_start?()
    @opponents.each_value { |opponent| 
      return opponent[:is_ready] unless opponent[:is_ready] # разве не if???
    }
    return true
  end

  # Оба игрока согласны на бой. Надо инициализировать бой на их устройствах.
  # Также надо передать информацию о доступных юнитах
  def create_battle_at_clients()
    MageLogger.instance.info "BattleDirector (UID=#{@uid}) has two opponents. Initialize battle on clients."
    
    player_units = DBResources.get_units(['stone_golem', 'mage', 'doghead', 'elf'])

    @opponents.each_value { |opponent| 
      opponent[:connection].send_message({:battle_uid => @uid, :units => player_units}, 'request_new_battle') unless opponent[:connection].nil?
    }

  end
end
