class AbstractSpell
  include Celluloid::Notifications

  attr_reader :completed, :life_time, :killed_units, :player_id, :uid
  attr_writer :channel

  STATES = [ :process, :affect, :wait, :empty ]

  def initialize(data, player_id)
    @data = data
    @completed = false
    @charges_count = 0
    @target_units = nil
    # @units_pool = {}
    @elapsed_time = 0
    # @horizontal_target = nil
    @create_at = Time.now.to_f

    @life_time = @data[:time_s]
    # communication channel
    @channel = nil

    @uid = data[:uid]
    # track killed units...
    @killed_units = 0

    @player_id = player_id
  end

  def achievementable?
    false
  end

  def set_target(horizontal_target, path_ways)
    half_horizontal_area = @data[:area] * 0.5
    @left_bound = horizontal_target - half_horizontal_area
    @right_bound = horizontal_target + half_horizontal_area

    @path_ways = path_ways
  end

  def decrease_targets_hp! damage_power
    unless @target_units.empty?
      @target_units.each do |target|
        hp_left = target.decrease_health_points damage_power
        @killed_units += 1 if hp_left < 0.0
      end
    end
  end

  def update(current_time, iteration_delta)
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
      finalize_spell
    end
  end

  def friendly_targets?
    true
  end

  private

  def finalize_spell
    @target_units = nil
    @path_ways = nil
    @completed = true
  end

  def process!
    find_targets!
  end

  def notificate_affected!
    publish(@channel,[ :send_custom_event,
      :addIcon,
      @data[:uid], @life_time * 1000, @target_units.map{|u| u.uid}
    ])
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
    @target_units = []

    @path_ways.flatten.each do |target|
      position = target.position
      if position >= @left_bound and position <= @right_bound
        @target_units << target
      end
    end
  end

  def compute_processing_stack(processing_type)
    case processing_type
      when :instant
        [:process, :affect]
      when :after_t
        [:wait, :process, :affect]
      when :effect_switch
        [:process, :affect, :wait, :remove_effect]
      when :over_time
        # In this case time parameter is a spell charges count
        @num_charges = @data[:num_charges].to_i || 1
        @life_time = @data[:time_s] * @num_charges
        [:process, :affect, :wait_charge] * @num_charges
      when :effect_switch_over_time
        # In this case time parameter is a spell charges count
        @num_charges = @data[:num_charges].to_i || 1
        @life_time = @data[:time_s] * @num_charges
        [:process] + [:affect, :wait_charge] * @num_charges
    end
  end
end
