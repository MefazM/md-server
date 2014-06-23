class Haste < AbstractSpell

  def initialize(data, player_id)
    super

    @states_stack = compute_processing_stack(:effect_switch)
    @value = data[:value_percentage].to_f || 0.8
  end

  def process!
    find_targets!
    notificate_affected!
  end

  def affect_targets!
    unless @target_units.empty?
      @target_units.each { |target|
        # puts(target.movement_speed, @value)
        target.movement_speed += target.unit_prototype[:movement_speed] * @value
        target.force_sync = true
      }
    end
  end

  def remove_effect!
    unless @target_units.empty?
      @target_units.each { |target|
        # puts(@value * target.movement_speed)
        target.movement_speed -= target.unit_prototype[:movement_speed] * @value
        target.force_sync = true
      }
    end
  end
end