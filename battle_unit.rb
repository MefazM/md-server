require "securerandom"
require 'pry'
require_relative 'ai_player.rb'
require_relative 'defines.rb'

class BattleUnit
  def initialize(unit_package, position = 0.1)
    # initialization unit by prototype
    @unit_prototype = DBResources.get_unit(unit_package)
    @unit_package = unit_package
    @uid = SecureRandom.hex(5)
    # additional params
    @status = UnitStatuses::MOVE
    @attack_period_time = 0
    @position = position

    @range_attack_power = rand(@unit_prototype[:range_attack_power_min]..@unit_prototype[:range_attack_power_max]) if @unit_prototype[:range_attack]
    @melee_attack_power = rand(@unit_prototype[:melee_attack_power_min]..@unit_prototype[:melee_attack_power_max]) if @unit_prototype[:melee_attack]

    @deferred_damage = []

    @health_points = @unit_prototype[:health_points]
    @movement_speed = @unit_prototype[:movement_speed]

    @attack_type = nil
    @attacked_unit = nil
  end

  def get_uid()
    @uid
  end

  def is_dead?()
    @status == UnitStatuses::DIE
  end

  def get_position()
    @position
  end

  def to_hash is_short = false
    data = {}
    if is_short
      data = {
        :uid => @uid, 
        :health_points => @health_points, 
        :movement_speed => @movement_speed, 
        :package => @unit_package
      }
    else
      data = { 
        :position => @position,
        :status => @status
      }
      data[:sequence_name] = @attack_type unless @attack_type.nil?
      data[:attacked_unit] = @attacked_unit unless @attacked_unit.nil?
    end

    data
  end

  def add_deffered_damage(attack_power, initial_position)
    @deferred_damage << {
      :power => attack_power,
      :position => initial_position,
    }
  end

  def decrease_health_points(decrease_by)
    @health_points -= decrease_by
  end

  def has_target?(opponent, attack_distantion)
    opponent[:units_pool].each do |uid, opponent_unit|
      distantion = opponent_unit.get_position() + @position
      if distantion > 1.0 - attack_distantion and attack_distantion < 1.0
        return true
      end
    end
    return false
  end

  def get_target(opponent, attack_distantion)
    opponent[:units_pool].each do |uid, opponent_unit|
      distantion = opponent_unit.get_position() + @position and attack_distantion < 1.0
      if distantion > 1.0 - attack_distantion
        return opponent_unit
      end
    end
    return nil
  end

  def process_deffered_damage(iteration_delta)
    @deferred_damage.each_with_index do |deferred, index|
      deferred[:position] += iteration_delta * 0.4 #! This is magick, 0.4 is a arrow speed!!

      if (deferred[:position] + @position >= 1.0)
        @health_points -= deferred[:power]
        @deferred_damage.delete_at(index)
      end
    end
  end  

  def update(opponent, iteration_delta)
    case @status
    when UnitStatuses::START_ATTACK
      @attack_period_time -= iteration_delta

      if @attack_period_time < 0

        case @attack_type
        when :melee_attack

          opponent_unit = get_target(opponent, @unit_prototype[:melee_attack_range])
          opponent_unit.decrease_health_points(@melee_attack_power) unless opponent_unit.nil?

          @status = UnitStatuses::DEFAULT
        when :range_attack
          
          opponent_unit = get_target(opponent, @unit_prototype[:range_attack_range])

          unless opponent_unit.nil?
            opponent_unit.add_deffered_damage(@range_attack_power, @position)
            @attacked_unit = opponent_unit.get_uid()
          end

          @status = UnitStatuses::FINISH_ATTACK
        end

      end
    when UnitStatuses::FINISH_ATTACK
      @status = UnitStatuses::DEFAULT
      # @attacked_unit = nil
      # @attack_type = nil

    when UnitStatuses::MOVE, UnitStatuses::DEFAULT
      if @unit_prototype[:melee_attack] and has_target?(opponent, @unit_prototype[:melee_attack_range])

        @status = UnitStatuses::START_ATTACK
        
        @attack_type = :melee_attack
        @attack_period_time = @unit_prototype[:melee_attack_speed]

      elsif @unit_prototype[:range_attack] and has_target?(opponent, @unit_prototype[:range_attack_range])

        @status = UnitStatuses::START_ATTACK

        @attack_type = :range_attack
        @attack_period_time = @unit_prototype[:range_attack_speed]

      else

        @status = UnitStatuses::MOVE
      end
    end

    process_deffered_damage(iteration_delta)

    if @health_points < 0.0
      @status = UnitStatuses::DIE
      # opponent[:units_pool].delete(uid)
    elsif @status == UnitStatuses::MOVE

      @position += iteration_delta * @unit_prototype[:movement_speed]
    end

  end
end
