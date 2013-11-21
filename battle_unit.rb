require "securerandom"
require 'pry'
require_relative 'ai_player.rb'
require_relative 'defines.rb'

class BattleUnit
  def initialize(unit_package, position = 0.1)
    # initialization unit by prototype
    @unit_prototype = DBResources.get_unit(unit_package)
    @unit_package = unit_package
    @uid = SecureRandom.hex(4)
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
  end

  def get_uid()
    @uid
  end

  def dead?()
    @status == UnitStatuses::DIE
  end

  def get_position()
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

  # Проверть есть ли на расстоянии атаки цель для этого юнита
  def get_target(opponent, attack_distantion)
    # Цикл через всех юнитов противника
    opponent[:units_pool].each do |uid, opponent_unit|
      distantion = opponent_unit.get_position() + @position
      if distantion > 1.0 - attack_distantion and attack_distantion < 1.0
        return opponent_unit
      end
    end
    # В последнюю очередь проверяем может ли юнит атаковать базу противника
    distantion = opponent[:main_building].get_position() + @position
    if distantion > 1.0 - attack_distantion and attack_distantion < 1.0
      return opponent[:main_building]
    end

    return nil
  end

  def process_deffered_damage(iteration_delta)
    @deferred_damage.each_with_index do |deferred, index|
      deferred[:position] += iteration_delta * 0.4 #! This is magick, 0.4 is a arrow speed!!

      if (deferred[:position] + @position >= 1.0)
        decrease_health_points(deferred[:power], deferred[:range_attack_damage_type])
        @deferred_damage.delete_at(index)
      end
    end
  end

  def update(opponent, iteration_delta)

    response = {}

    case @status
    when UnitStatuses::ATTACK
      @attack_period_time -= iteration_delta

      if @attack_period_time < 0

        case @attack_type
        when :melee_attack
          opponent_unit = get_target(opponent, @unit_prototype[:melee_attack_range])

          opponent_unit.decrease_health_points(
            @melee_attack_power,
            @unit_prototype[:melee_attack_damage_type]
          ) unless opponent_unit.nil?

        when :range_attack
          opponent_unit = get_target(opponent, @unit_prototype[:range_attack_range])

          unless opponent_unit.nil?
            opponent_unit.add_deffered_damage(
              @range_attack_power,
              @position,
              @unit_prototype[:range_attack_damage_type]
            )
            # спрайт для дистанционной аттаки
            response[:pr] = {:c => opponent_unit.get_uid()}
          end
        end

        @status = UnitStatuses::DEFAULT
      end

    when UnitStatuses::MOVE, UnitStatuses::DEFAULT
      if @unit_prototype[:melee_attack] and get_target(opponent, @unit_prototype[:melee_attack_range])

        @status = UnitStatuses::ATTACK

        @attack_type = :melee_attack
        @attack_period_time = @unit_prototype[:melee_attack_speed]

        response[:sq] = :melee_attack

      elsif @unit_prototype[:range_attack] and get_target(opponent, @unit_prototype[:range_attack_range])

        @status = UnitStatuses::ATTACK

        @attack_type = :range_attack
        @attack_period_time = @unit_prototype[:range_attack_speed]

        response[:sq] = :range_attack

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

    response[:p] = @position.round(3)
    response[:s] = @status

    response
  end
end
