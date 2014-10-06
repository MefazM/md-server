class Bless < AbstractSpell
  def initialize(data, player_id)
    super
    @states_stack = compute_processing_stack(:effect_switch)
    @value = data[:value_percentage].to_f || 0.0
  end

  def process!
    find_targets! :bless
    notificate_affected!
  end

  def affect_targets!
    data = [
      {:var => :range_attack_power, :val => @value, :type => :add, :percentage => true},
      {:var => :melee_attack_power, :val => @value, :type => :add, :percentage => true}
    ]

    @target_units.each { |target| target.affect(:bless, data)}
  end

  def remove_effect!
    @target_units.each { |target| target.remove_effect :bless }
  end
end
