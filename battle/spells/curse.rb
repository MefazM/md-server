class Curse < AbstractSpell

  def initialize data
    super
    @states_stack = compute_processing_stack(:effect_switch)
    @value = data[:value_percentage].to_f || 0.0
  end

  def friendly_targets?
    false
  end

  def process!
    find_targets!
    notificate_affected!
  end

  def affect_targets!
    unless @target_units.empty?
      @target_units.each { |target|
        unit_prototype = target.unit_prototype
        target.range_attack_power -= unit_prototype[:range_attack_power_min] * @value unless target.range_attack_power.nil?
        target.melee_attack_power -= unit_prototype[:melee_attack_power_min] * @value unless target.melee_attack_power.nil?
      }
    end
  end

  def remove_effect!
    unless @target_units.empty?
      @target_units.each { |target|
        unit_prototype = target.unit_prototype
        target.range_attack_power += unit_prototype[:range_attack_power_min] * @value unless target.range_attack_power.nil?
        target.melee_attack_power += unit_prototype[:melee_attack_power_min] * @value unless target.melee_attack_power.nil?
      }
    end
  end
end