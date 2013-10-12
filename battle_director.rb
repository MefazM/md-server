require "securerandom"
require 'pry'

require_relative 'ai_player.rb'

module BattleStatuses
  PENDING = 1
  READY_TO_START = 2
  IN_PROGRESS = 3
end

module UnitStatuses
  MOVE = 1
  ATTACK = 2
  ATTACK_MELEE = 5
  ATTACK_RANGE = 6  
  DIE = 3
  IDLE = -1
  ATTACK_NOT_READY = -2
end

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
      :units_pool => {}, 
      :timings => {}
    }
  end

  def set_opponent_ready(player_id)
    @opponents[player_id][:is_ready] = true
    if (ready_to_start?)
      start()
    end
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
    if (iteration_delta > 100)
      @iteration_time = current_time

      attack_phase()
      deffered_attack_phase(iteration_delta)

      @opponents.each do |player_id, opponent|
        response = {}
        opponent[:units_pool].each do |uid, unit|
          unit_status = unit[:status]
          if unit[:health_points] < 0
            unit_status = UnitStatuses::DIE
            opponent[:units_pool].delete(uid)
          elsif unit_status == UnitStatuses::MOVE
            unit[:position] += iteration_delta * 0.001 * unit[:movement_speed]
          end
          response[uid] = { 
            :position => unit[:position], 
            :status => unit_status
          }

          response[uid][:attacked_unit] = unit[:attacked_unit] unless unit[:attacked_unit].nil?

        end
        broadcast_response({:units_data => response, :player_id => player_id}, 'sync_client')
      end
    end
    # /World update

    # 
    # Ping update
    #
    if current_time - @ping_time > 500
      @ping_time = current_time
      @opponents.each do |player_id, opponent|
        opponent[:connection].make_response({:time => current_time}, 'ping') unless opponent[:connection].nil?
      end
    end
    # /Ping update

    # 
    # Default unit spawn
    
    if current_time - @default_unit_spawn_time > 5000
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

  def enable_ai(ai_uid)
    @opponents_indexes << ai_uid
    @opponents[ai_uid] = { 
      :player => AiPlayer.new('token'),
      :connection => nil,
      :is_ready => true, 
      :units_pool => {}, 
      :timings => {}
    }    
  end

  def is_started?()
    @status == BattleStatuses::IN_PROGRESS
  end  

private

  def add_unit_to_pool(opponent, unit_pakage)
    # initialization unit by prototype
    unit = $db_resources.get_unit(unit_pakage)
    # additional params
    unit[:status] = UnitStatuses::MOVE
    unit[:attack_period_time] = 0
    unit[:position] = 0.1
    unit[:range_attack_power] = rand(unit[:range_attack_power_min]..unit[:range_attack_power_max]) if unit[:range_attack] == 1
    unit[:melee_attack_power] = rand(unit[:melee_attack_power_min]..unit[:melee_attack_power_max]) if unit[:melee_attack] == 1

    unit[:deferred_damage] = []

    unit_uid = SecureRandom.hex(5)
    opponent[:units_pool][unit_uid] = unit
    
    {:uid => unit_uid, :health_points => unit[:health_points], 
      :movement_speed => unit[:movement_speed], :package => unit_pakage}
  end

  def broadcast_response(data, action)
    @opponents.each_value { |opponent| 
      opponent[:connection].make_response(data, action) unless opponent[:connection].nil?
    }
  end 

  def get_timer()
    Time.now.to_f * 1000
  end

  def deffered_attack_phase(iteration_delta)
    @opponents.each do |player_id, opponent|
      opponent[:units_pool].each do |uid, unit|

        unit[:deferred_damage].each_with_index do |deferred_damage, index|
          #! This is magick, 0.001 - to cast ms to seconds, 0.4 is a arrow speed
          deferred_damage[:initial_position] += iteration_delta * 0.001 * 0.4

          if (deferred_damage[:initial_position] + unit[:position] >= 1.0)
            unit[:health_points] -= deferred_damage[:power]
            unit[:deferred_damage].delete_at(index)
          end
        end
      end
    end
  end

  def attack_unit(unit, opponent)
    current_time = get_timer()
    attack_timer_ready = unit[:attack_period_time] < current_time

    opponent[:units_pool].each do |uid, opponent_unit|
      # Checking the collision zone of attack units
      attack_distantion = opponent_unit[:position] + unit[:position]
      ####
      if unit[:range_attack] == 1
        if attack_distantion > 1.0 - unit[:range_attack_range] and attack_distantion < 1.0
          # Test attack timer
          if attack_timer_ready
            opponent_unit[:deferred_damage] << {
              :power => unit[:range_attack_power],
              :initial_position => unit[:position],
            }

          unit[:attack_period_time] = current_time + unit[:range_attack_speed]
            return UnitStatuses::ATTACK_RANGE, uid
          end
          return UnitStatuses::IDLE
        end
      end
      ####
      
      if unit[:melee_attack] == 1
        if attack_distantion > 1.0 - unit[:melee_attack_range] and attack_distantion < 1.0
          # Test attack timer
          if attack_timer_ready
            opponent_unit[:health_points] -= unit[:melee_attack_power]
            unit[:attack_period_time] = current_time + unit[:melee_attack_speed]
            return UnitStatuses::ATTACK_MELEE
          end
          return UnitStatuses::IDLE
        end
      end

    end
    return attack_timer_ready ? UnitStatuses::MOVE : unit[:status]#UnitStatuses::ATTACK
  end

  def attack_phase()
    opponent_1 = @opponents[@opponents_indexes[0]]
    opponent_2 = @opponents[@opponents_indexes[1]]

    opponent_1[:units_pool].each do |uid, unit|
      unit[:status], unit[:attacked_unit] = attack_unit(unit, opponent_2)
    end

    opponent_2[:units_pool].each do |uid, unit|
      unit[:status], unit[:attacked_unit] = attack_unit(unit, opponent_1)
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
      return opponent[:is_ready] unless opponent[:is_ready]
    }
    return true
  end
end
