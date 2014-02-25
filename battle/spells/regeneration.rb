#
#
class Regeneration < AbstractSpell
 def initialize(data, brodcast_callback)
    super

    @states_stack = compute_processing_stack(:over_time)
    @heal_per_charge = data[:heal_per_charge].to_f || 0.0
    # @sum_d = 0
  end

  def process!
    find_targets!
    notificate_affected!
  end

  def affect_targets!
    unless @target_units.empty?
      @target_units.each { |target| target.increase_health_points(@heal_per_charge) }
    end
  end
end