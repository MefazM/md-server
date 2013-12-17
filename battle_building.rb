require "securerandom"
require 'pry'
require_relative 'ai_player.rb'

class BattleBuilding
  def initialize(package, position = 0.1)
    # initialization unit by prototype
    @unit_prototype = {
      :health_points => 200
    }
    @package = package
    @uid = SecureRandom.hex(4)
    # additional params
    @position = position
    @deferred_damage = []
    @health_points = @unit_prototype[:health_points]

    @changed = false
  end

  def changed?
    changed = @changed
    @changed = false

    changed
  end

  def uid()
    @uid
  end

  def health_points()
    @health_points
  end

  def dead?()
    @health_points < 0
  end

  def position()
    @position
  end

  def to_a
    [@uid, @package, @position, @health_points]
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
    @health_points -= decrease_by
    @changed = true
  end

  def process_deffered_damage(iteration_delta)
    @deferred_damage.each_with_index do |deferred, index|
      deferred[:position] += iteration_delta * 0.4 #! This is magick, 0.4 is a arrow speed!!
      if (deferred[:position] + @position >= 1.0)
        decrease_health_points(deferred[:power], deferred[:range_attack_damage_type])
        @deferred_damage.delete_at(index)
        @changed = true
      end
    end
  end

  def update(iteration_delta)
    process_deffered_damage(iteration_delta)
  end
end
