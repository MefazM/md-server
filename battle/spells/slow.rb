class Slow < AbstractSpell
  def initialize(data, player_id)
    super
    @states_stack = compute_processing_stack(:effect_switch)
    @value = data[:value_percentage].to_f || 0.0
  end

  def friendly_targets?
    false
  end

  def affect_targets!
    data = [
      {:var => :movement_speed, :val => @value, :type => :reduce, :percentage => true}
    ]

    @target_units.each { |target| target.affect(:slow, data)}
  end

  def remove_effect!
    @target_units.each { |target| target.remove_effect :slow }
  end
end
