#
# INSTANT HEAL
class Stun < AbstractSpell
  def initialize(data, brodcast_callback)
    super

    @states_stack = compute_processing_stack(:effect_switch)
  end

  def friendly_targets?
    false
  end

  def process!
    find_targets!
    notificate_affected!
  end

  def affect_targets!
    unless @target_units.empty?
      @target_units.each { |target|
        @prev_status = target.status
        target.status = BattleUnit::STUNED
        target.force_sync = true
      }
    end
  end

  def remove_effect!
    unless @target_units.empty?
      @target_units.each { |target|
        target.status = @prev_status
        target.force_sync = true
      }
    end
  end
end