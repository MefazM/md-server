#
#
class Poison < AbstractSpell
 def initialize(data, player_id)
    super
    @states_stack = compute_processing_stack(:over_time)
    @damage_per_charge = data[:damage_per_charge].to_f || 0.0
  end

  def friendly_targets?
    false
  end

  def affect_targets!
    decrease_targets_hp! @damage_per_charge
  end
end