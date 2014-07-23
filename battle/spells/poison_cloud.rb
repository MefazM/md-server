class PoisonCloud < AbstractSpell
 def initialize(data, player_id)
    super
    @states_stack = compute_processing_stack(:over_time)
    @damage_per_charge = data[:damage_per_charge].to_f || 0.0
    @target_units = []
  end

  def friendly_targets?
    false
  end

  def affect_targets!
    decrease_targets_hp! @damage_per_charge
  end

  def finalize_spell
    @target_units.each {|unit| unit.remove_effect :slow }
    super
  end

  def find_targets!
    units = []

    @path_ways.flatten.each do |target|
      position = target.position
      if position >= @left_bound and position <= @right_bound
        units << target
      end
    end

    units_than_leave_area = @target_units - units
    units_than_leave_area.each {|unit| unit.remove_effect :slow }

    data = [
      {:var => :movement_speed, :val => 0.5, :type => :reduce, :percentage => true}
    ]

    units.each { |target| target.affect(:slow, data)}

    @target_units = units
  end
end
