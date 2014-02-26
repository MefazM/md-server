class AbstractSpell
  STATES = [ :process, :affect, :wait, :empty ]

  attr_reader :completed, :life_time
  attr_writer :units_pool, :target_area

  def initialize(data, brodcast_callback)
    @data = data
    @brodcast_callback = brodcast_callback

    @completed = false
    @charges_count = 0
    @target_units = []
    @target_units_ids = []
    @units_pool = {}
    @elapsed_time = 0
    @target_area = nil
    @create_at = Time.now.to_f

    @life_time = @data[:time_s]
  end

  def update!(current_time, iteration_delta)
    state = @states_stack[0] || :empty

    @elapsed_time = current_time - @create_at

    case state
    # Find targets and affect them
    when :process
      process!
      @states_stack.delete_at(0)

    # Affect already allocated targets
    when :affect
      affect_targets!
      @states_stack.delete_at(0)
    # Wait for spell life time expires
    when :wait
      if @elapsed_time > @life_time
        @states_stack.delete_at(0)
      end
    # Wait for delay between spell charges expire
    when :wait_charge
      if @charges_count < (@elapsed_time / @data[:time_s])
        @charges_count += 1
        @states_stack.delete_at(0)
      end
    # Remove spell effect callback
    when :remove_effect
      remove_effect!

      @states_stack.delete_at(0)
    # Spell is ready if task stack is empty
    when :empty
      # puts("FINISH!!!!!")
      @units_pool = nil
      @completed = true
    end
  end

  def friendly_targets?
    true
  end

  private

  def process!
    find_targets!
  end

  def notificate_affected!
    @brodcast_callback.call(:addIcon, [@data[:uid], @life_time * 1000, @target_units_ids])
  end

  def affect_targets!
    unless @target_units.empty?
      @target_units.each { |target| puts("T: #{target.uid} - affected") }
    end
  end

  def remove_effect!
    unless @target_units.empty?
      @target_units.each { |target| puts("T: #{target.uid} - dispel") }
    end
  end

  def find_targets!
    area = @data[:area]

    left_bound = @target_area - area * 0.5
    right_bound = @target_area + area * 0.5

    @units_pool.each do |target|
      position = target.position
      if position >= left_bound and position <= right_bound
        @target_units << target
        @target_units_ids << target.uid
      end
    end
  end

  def compute_processing_stack(processing_type)
    case processing_type
      when :instant
        # @life_time = data[:time]
        [:process, :affect]
      when :after_t
        [:wait, :process, :affect]

      when :effect_switch
        [:process, :affect, :wait, :remove_effect]

      when :over_time
        # In this case time parameter is a spell charges count
        @num_charges = @data[:num_charges].to_i || 1
        @life_time = @data[:time_s] * @num_charges
        [:process] + [:affect, :wait_charge] * @num_charges
    end
  end
end