require "securerandom"
require 'pry'
require_relative 'ai_player.rb'
require_relative 'defines.rb'

class BattleUnit
  def initialize(unit_package, position = 0.0)
    # initialization unit by prototype
    @unit_prototype = UnitsFactory.instance.units(unit_package)
    @unit_package = unit_package
    @uid = SecureRandom.hex(4)
    # additional params
    @status = UnitStatuses::IDLE
    @attack_period_time = 0
    @position = position

    @range_attack_power = rand(@unit_prototype[:range_attack_power_min]..@unit_prototype[:range_attack_power_max]) if @unit_prototype[:range_attack]
    @melee_attack_power = rand(@unit_prototype[:melee_attack_power_min]..@unit_prototype[:melee_attack_power_max]) if @unit_prototype[:melee_attack]

    @deferred_damage = []

    @health_points = @unit_prototype[:health_points]
    @movement_speed = @unit_prototype[:movement_speed]

    @attack_type = nil
  end

  def package
    @unit_package
  end

  def uid()
    @uid
  end

  def dead?()
    @status == UnitStatuses::DIE
  end

  def position()
    @position
  end

  def to_hash
    data = {
      :uid => @uid,
      :health_points => @health_points,
      :movement_speed => @movement_speed,
      :package => @unit_package
    }

    data
  end

  def to_a
    [@uid, @health_points, @movement_speed, @unit_package]
  end

  def add_deffered_damage(attack_power, initial_position, range_attack_damage_type)
    @deferred_damage << {
      :power => attack_power,
      :position => initial_position,
      :range_attack_damage_type => range_attack_damage_type
    }
  end

  def decrease_health_points(decrease_by, attack_type)
    # Сила аттаки уменьшается в двое, если юнит имеет защиту от такого типа атак.
    resist_type = @unit_prototype[:resist_type]
    decrease_by *= 0.5 if resist_type and attack_type == resist_type

    @health_points -= decrease_by
  end

  def process_deffered_damage(iteration_delta)
    @deferred_damage.each_with_index do |deferred, index|
      deferred[:position] += iteration_delta * 0.4 #! This is magick, 0.4 is a arrow speed!!

      if (deferred[:position] + @position >= 1.0)
        decrease_health_points(deferred[:power], deferred[:range_attack_damage_type])
        @deferred_damage.delete_at(index)

        return true
      end
    end

    return false
  end

  def attack?(opponent_position, attack_type)
    # If unit has not such kind of attack
    # return false
    return false unless @unit_prototype[attack_type]
    # Calculate distance
    attack_range = @unit_prototype["#{attack_type}_range".to_sym]
    distantion = opponent_position + @position

    return distantion > (1.0 - attack_range) # and distantion < 1.0
  end

  def attack(opponent_unit, attack_type)
    case attack_type
    when :melee_attack
      opponent_unit.decrease_health_points(
        @melee_attack_power,
        @unit_prototype[:melee_attack_damage_type]
      )

      @attack_period_time = @unit_prototype[:melee_attack_speed]
      @status = UnitStatuses::ATTACK_MELEE

    when :range_attack
      opponent_unit.add_deffered_damage(
        @range_attack_power,
        @position,
        @unit_prototype[:range_attack_damage_type]
      )

      @attack_period_time = @unit_prototype[:range_attack_speed]
      @status = UnitStatuses::ATTACK_RANGE
    end
  end

  def status
    @status
  end

  def can_attack?
    return @status == UnitStatuses::MOVE || @status == UnitStatuses::IDLE
  end

  def update(iteration_delta)

    process_deffered_damage(iteration_delta)

    case @status
    when UnitStatuses::MOVE
      @position += iteration_delta * @unit_prototype[:movement_speed]

    when UnitStatuses::ATTACK_MELEE, UnitStatuses::ATTACK_RANGE
      @attack_period_time -= iteration_delta
      @status = UnitStatuses::IDLE if @attack_period_time < 0

    when UnitStatuses::IDLE
      @status = UnitStatuses::MOVE

    end
    @status = UnitStatuses::DIE if @health_points < 0.0
  end
end
