#
#
class Thunder < AbstractSpell
 def initialize(data, brodcast_callback)
    super

    @states_stack = compute_processing_stack(:over_time)
    @damage_per_charge = data[:damage_per_charge].to_f || 0.0
  end

  def friendly_targets?
    false
  end

  def affect_targets!
    find_targets!

    unless @target_units.empty?
      @target_units.each { |target| target.decrease_health_points(@damage_per_charge) }
    end
  end
end