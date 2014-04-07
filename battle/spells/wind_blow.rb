#
# INSTANT HEAL
class WindBlow < AbstractSpell
  def initialize data
    super
    @states_stack = compute_processing_stack(:instant)
    @offset = data[:move_offset_percentage].to_f || 0.0
  end

  def friendly_targets?
    false
  end

  def affect_targets!
    unless @target_units.empty?
      @target_units.each { |target|
        position = target.position - @offset
        position = 0.0 if position < 0.0
        # puts("#{target.position - @offset}, #{target.position}, #{@offset}")
        target.position = position
        target.force_sync = true
      }
    end
  end
end