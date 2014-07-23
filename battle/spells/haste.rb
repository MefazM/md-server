class Haste < AbstractSpell
  def initialize(data, player_id)
    super

    @states_stack = compute_processing_stack(:effect_switch)
    @value = data[:value_percentage].to_f || 0.8
  end

  def process!
    find_targets!
    notificate_affected!
  end

  def affect_targets!
    data = [
      {:var => :movement_speed, :val => @value, :type => :add, :percentage => true}
    ]

    @target_units.each { |target| target.affect(:haste, data)}
  end

  def remove_effect!
    @target_units.each { |target| target.remove_effect :haste }
  end
end
