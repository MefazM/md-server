class Curse < AbstractSpell
  def initialize(data, player_id)
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
    data = [
      {:var => :range_attack_power, :val => @value, :type => :reduce, :percentage => true},
      {:var => :melee_attack_power, :val => @value, :type => :reduce, :percentage => true}
    ]

    @target_units.each { |target| target.affect(:curse, data)}
  end

  def remove_effect!
    @target_units.each { |target| target.remove_effect :curse }
  end
end
