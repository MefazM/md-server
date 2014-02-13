class AbstractSpell
  STATES = [ :process, :affect, :wait, :empty ]
  attr_reader :completed

  def initialize(data, target_point, target_units_pool)
    @data = data
    @target_point = target_point
    @targets = []
    @target_units_pool = target_units_pool
    @time = Time.now.to_f + data[:time]

    @states_stack = case data[:processing_type]
      when :instant
        [:process]
      when :during_t
        [:process, :affect]
      when :after_t
        [:wait, :process]
      when :effect_switch
        [:process, :wait, :remove_effect]
    end

    @completed = false
  end

  def affect!(target)
    puts("Implement affecting for this spell!")
  end

  def remove_effect!
    puts("Implement effect removing for this spell!")
  end

  def process!(current_time)
    state = @states_stack[0] || :empty
    case state
    when :process
      find_targets!
      affect_targets!
      @states_stack.delete_at 0
    when :affect
      affect_targets!
      if @time < current_time
        @states_stack.delete_at 0
      end
    when :wait
      if @time < current_time
        @states_stack.delete_at 0
      end
    when :remove_effect
      remove_effect!
      @states_stack.delete_at 0
    when :empty
      @completed = true
    end
  end

  private

  def affect_targets!
    unless @targets.empty?
      @targets.each { |target| affect(target) }
    end
  end

  def find_targets!
    area = @data[:area]
    left_bound = @target_point - area * 0.5
    right_bound = @target_point + area * 0.5

    @target_units_pool.each do |target|
      position = target.position
      if position >= left_bound and position <= right_bound
        @targets << target
      end
    end

    @target_units_pool = nil
  end
end