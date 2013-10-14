require "securerandom"
require 'pry'
require_relative 'ai_player.rb'
require_relative 'defines.rb'

class BattleDirector

  def initialize()
    @opponents = {}
    @status = BattleStatuses::PENDING
    @uid = SecureRandom.hex(5)
    @opponents_indexes = []
    @iteration_time = get_timer()
    @ping_time = get_timer()
    @default_unit_spawn_time = 0
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
  end

  def enable_ai(ai_uid)
    @opponents_indexes << ai_uid
    @opponents[ai_uid] = { 
      :player => AiPlayer.new('token'),
      :connection => nil,
      :is_ready => true, 
      :units_pool => {}, 
    }    
  end  

  def set_opponent_ready(player_id)
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
          unit_status = unit[:status]
          if unit[:health_points] < 0
            unit_status = UnitStatuses::DIE
            opponent[:units_pool].delete(uid)
          elsif unit_status == UnitStatuses::MOVE
            unit[:position] += iteration_delta * unit[:movement_speed]
          end

          resp = { 
            :position => unit[:position], 
            :status => unit_status
          }

          resp[:sequence_name] = unit[:attack_type] unless unit[:attack_type].nil?
          resp[:attacked_unit] = unit[:attacked_unit] unless unit[:attacked_unit].nil?

          response[uid] = resp
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
        opponent[:connection].make_response({:time => current_time}, 'ping') unless opponent[:connection].nil?
      end
    end
    # /Ping update

    # 
    # Default unit spawn
    if current_time - @default_unit_spawn_time > Timings::DEFAULT_UNITS_SPAWN_TIME
      @default_unit_spawn_time = current_time
      @opponents.each do |player_id, opponent|     
        unit_pakage = opponent[:player].get_default_unit_package()
        spawn_data = add_unit_to_pool(opponent, unit_pakage)
        spawn_data[:owner_id] = player_id
        
        broadcast_response(spawn_data, 'spawn_unit')
      end
    end
    # /Default unit spawn
  end 

private

  def get_timer()
    Time.now.to_f
  end

  def broadcast_response(data, action)
    @opponents.each_value { |opponent| 
      opponent[:connection].make_response(data, action) unless opponent[:connection].nil?
    }
  end   

  def add_unit_to_pool(opponent, unit_pakage)
    # initialization unit by prototype
    unit = DBResources.get_unit(unit_pakage)
    unit_uid = SecureRandom.hex(5)
    # additional params
    unit[:status] = UnitStatuses::MOVE
    unit[:attack_period_time] = 0
    unit[:position] = 0.1
    unit[:range_attack_power] = rand(unit[:range_attack_power_min]..unit[:range_attack_power_max]) if unit[:range_attack]
    unit[:melee_attack_power] = rand(unit[:melee_attack_power_min]..unit[:melee_attack_power_max]) if unit[:melee_attack]
    unit[:deferred_damage] = []
    unit[:uid] = unit_uid
    opponent[:units_pool][unit_uid] = unit
    
    return {:uid => unit_uid, :health_points => unit[:health_points], :movement_speed => unit[:movement_speed], :package => unit_pakage}
  end

  def deffered_attack_phase(iteration_delta)
    @opponents.each do |player_id, opponent|
      opponent[:units_pool].each do |uid, unit|
        unit[:deferred_damage].each_with_index do |deferred_damage, index|
          deferred_damage[:initial_position] += iteration_delta * 0.4 #! This is magick, 0.4 is a arrow speed!!
          if (deferred_damage[:initial_position] + unit[:position] >= 1.0)
            unit[:health_points] -= deferred_damage[:power]
            unit[:deferred_damage].delete_at(index)
          end
        end
      end
    end
  end

  def has_target(opponent, position, attack_distantion)
    opponent[:units_pool].each do |uid, opponent_unit|
      distantion = opponent_unit[:position] + position
      if distantion > 1.0 - attack_distantion and attack_distantion < 1.0
        return true
      end
    end
    return false
  end

  def get_target(opponent, position, attack_distantion)
    opponent[:units_pool].each do |uid, opponent_unit|
      distantion = opponent_unit[:position] + position and attack_distantion < 1.0
      if distantion > 1.0 - attack_distantion
        return opponent_unit
      end
    end
    return nil
  end

  def make_attack(opponent, unit, iteration_delta)
    case unit[:status]
    when UnitStatuses::START_ATTACK
      unit[:attack_period_time] -= iteration_delta
      if unit[:attack_period_time] < 0
        case unit[:attack_type]
        when :melee_attack
          opponent_unit = get_target(opponent, unit[:position], unit[:melee_attack_range])
          opponent_unit[:health_points] -= unit[:melee_attack_power] unless opponent_unit.nil?
          unit[:status] = UnitStatuses::DEFAULT
        when :range_attack
          opponent_unit = get_target(opponent, unit[:position], unit[:range_attack_range])
          unless opponent_unit.nil?
            opponent_unit[:deferred_damage] << {
              :power => unit[:range_attack_power],
              :initial_position => unit[:position],
            }
            unit[:attacked_unit] = opponent_unit[:uid]
          end
          unit[:status] = UnitStatuses::FINISH_ATTACK
        end
      end
    when UnitStatuses::FINISH_ATTACK
      unit[:status] = UnitStatuses::DEFAULT
    when UnitStatuses::MOVE, UnitStatuses::DEFAULT
      if unit[:melee_attack] and has_target(opponent, unit[:position], unit[:melee_attack_range])
        unit[:status] = UnitStatuses::START_ATTACK
        unit[:attack_type] = :melee_attack 
        unit[:attack_period_time] = unit[:melee_attack_speed]
      elsif unit[:range_attack] and has_target(opponent, unit[:position], unit[:range_attack_range])
        unit[:status] = UnitStatuses::START_ATTACK
        unit[:attack_type] = :range_attack
        unit[:attack_period_time] = unit[:range_attack_speed]
      else
        unit[:status] = UnitStatuses::MOVE
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
end
