class Thunder < AbstractSpell
 def initialize(data, player_id)
    super

    @states_stack = compute_processing_stack(:over_time)
    @damage_per_charge = data[:damage_per_charge].to_f || 0.0

    @units_to_kill = data[:units_to_kill].to_i
  end

  def friendly_targets?
    false
  end

  def affect_targets!
    decrease_targets_hp! @damage_per_charge
  end

  def achievementable?
    @killed_units > @units_to_kill
  end
end
