#
# BOMB
class Bomb < AbstractSpell
  def initialize data
    super
    @states_stack = compute_processing_stack(:after_t)
    @damage_power = data[:power].to_f || 0.0
  end

  def friendly_targets?
    false
  end

  def affect_targets!
    unless @target_units.empty?
      @target_units.each { |target| target.decrease_health_points(@damage_power) }
    end
  end
end