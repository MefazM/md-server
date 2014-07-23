class Bomb < AbstractSpell
  def initialize(data, player_id)
    super
    @states_stack = compute_processing_stack(:after_t)
    @damage_power = data[:power].to_f || 0.0
  end

  def friendly_targets?
    false
  end

  def affect_targets!
    decrease_targets_hp! @damage_power
  end
end
