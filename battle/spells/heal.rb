#
# INSTANT HEAL
class Heal < AbstractSpell
  def initialize(data, player_id)
    super
    @states_stack = compute_processing_stack(:instant)
    @heal = data[:heal_power].to_f || 0.0
  end

  def affect_targets!
    unless @target_units.empty?
      @target_units.each { |target| target.increase_health_points(@heal) }
    end
  end
end