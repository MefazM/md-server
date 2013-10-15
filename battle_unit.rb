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

  def respond_status? (status)
    @status == status
  end

  def get_status()
    @status
  end

  def to_hash is_short = false
    data = {}

    if is_short
      data = {:uid => @uid, :health_points => @health_points, :movement_speed => @movement_speed, :package => @unit_package}
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

  def is_dead?
    @health_points < 0
  end

  def set_status(status)
    @status = status
  end

  def move(iteration_delta)
    @position += iteration_delta * @unit_prototype[:movement_speed]
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

  def decrease_attack_timer(iteration_delta)
    @attack_period_time -= iteration_delta
    @attack_period_time
  end

  def set_attack_period_time(attack_period_time)
    @attack_period_time = @unit_prototype[attack_period_time]
  end

  def add_deffered_damage(attack_power, initial_position)
    @deferred_damage << {
      :power => attack_power,
      :position => initial_position,
    }
  end

  def get_current_attack_type()
    @attack_type
  end

  def set_current_attack_type(attack_type)
    @attack_type = attack_type
  end

  def get_position()
    @position
  end

  def get_attack_option(attack_option)
    @unit_prototype[attack_option]
  end

  def decrease_health_points(decrease_by)
    @health_points -= decrease_by
  end

  def set_current_attacked_unit(uid)
    @attacked_unit = uid
  end

  def has_attack? (attack_type)
    @unit_prototype[attack_type]
  end

  def get_range_attack_power()
    @range_attack_power
  end

  def get_melee_attack_power()
    @melee_attack_power
  end  
end
