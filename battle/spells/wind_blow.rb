class WindBlow < AbstractSpell
  def initialize(data, player_id)
    super
    @states_stack = compute_processing_stack(:instant)
    @offset = data[:move_offset_percentage].to_f || 0.0
  end

  def friendly_targets?
    false
  end

  def affect_targets!
    data = [
      {:var => :position, :val => @offset, :type => :reduce}
    ]

    @target_units.each { |target| target.affect( nil, data)}
  end
end
