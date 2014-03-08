require_relative 'ai_player.rb'
class BattleUnit
  @@uid_iteratior = 0
  # Unit states
  MOVE = 1
  DIE = 3
  ATTACK_MELEE = 4
  ATTACK_RANGE = 5
  IDLE = 42
  # Spell-based states
  STUNED = 101
  #
  NO_TARGET = -1

  PATH_COUNT = 10

  NEAREST_TARGET_DEFAULT_OFFSET = 0.25

  attr_accessor :uid, :position, :status, :name,
    :movement_speed, :force_sync, :range_attack_power, :melee_attack_power, :target, :path_id, :health_points

  attr_reader :health_points, :unit_prototype, :initiative, :body_width, :nearest_target_offset

  def initialize(name, position = 0.0)
    # initialization unit by prototype
    @unit_prototype = UnitsFactory.instance.units(name)
    @name = name
    @uid = "u#{@@uid_iteratior}"
    @@uid_iteratior += 1
    # additional params
    @status = IDLE
    @prev_status = IDLE
    @attack_period_time = 0
    @position = position
    @range_attack_power = rand(@unit_prototype[:range_attack_power_min]..@unit_prototype[:range_attack_power_max]) if @unit_prototype[:range_attack]
    @melee_attack_power = rand(@unit_prototype[:melee_attack_power_min]..@unit_prototype[:melee_attack_power_max]) if @unit_prototype[:melee_attack]
    @deferred_damage = []
    @health_points = @unit_prototype[:health_points]
    @movement_speed = @unit_prototype[:movement_speed]
    @attack_type = nil

    @force_sync = false

    @initiative = rand(0..10000)


    @body_width = 0.015


    @nearest_target_offset = 1.0 - (@unit_prototype[:range_attack] ? @unit_prototype[:range_attack_range] : NEAREST_TARGET_DEFAULT_OFFSET)

    @target = nil

    # ObjectSpace.define_finalizer(self, self.class.method(:finalize).to_proc)
  end

  def target_leave_path?
    !@target.nil? && !@target.static?  && @target.path_id != @path_id
  end

  def has_no_target?
    @target.nil? || @target.dead?
  end

  def self.finalize(id)
    puts "Battle Unit| #{id} dying at #{Time.new}"
  end

  def dead?()
    @health_points < 0.0
  end

  def sync_data
    hp_scale = @health_points.to_f / @unit_prototype[:health_points].to_f
    data = [@uid, @status, @path_id, @position.round(3), hp_scale]


    target = @target.nil? ? NO_TARGET : @target.uid

    data << target

    animation_scale = case @status
    when MOVE
      @movement_speed / @unit_prototype[:movement_speed]
    # when ATTACK_MELEE, ATTACK_RANGE
    else
      1.0
    end

    data << animation_scale
    # data << @movement_speed
    data
  end

  def add_deffered_damage(attack_power, initial_position, range_attack_damage_type)
    @deferred_damage << {
      :power => attack_power,
      :position => initial_position,
      :range_attack_damage_type => range_attack_damage_type
    }
  end

  def decrease_health_points(decrease_by, attack_type = nil)
    # Сила аттаки уменьшается в двое, если юнит имеет защиту от такого типа атак.
    resist_type = @unit_prototype[:resist_type]
    decrease_by *= 0.5 if resist_type and attack_type == resist_type
    @health_points -= decrease_by

    # puts("HP: #{@health_points}")

    @force_sync = true
  end

  def increase_health_points(increase_by)
    @health_points = [@unit_prototype[:health_points], @health_points + increase_by].min

    # puts("HP: #{@health_points}")

    @force_sync = true
  end

  def process_deffered_damage(iteration_delta)
    @deferred_damage.each_with_index do |deferred, index|
      deferred[:position] += iteration_delta * 0.4 #! This is magick, 0.4 is a arrow speed!!
      if (deferred[:position] + @position >= 1.0)
        decrease_health_points(deferred[:power], deferred[:range_attack_damage_type])
        @deferred_damage.delete_at(index)
        return true
      end
    end
    return false
  end

  def attack?(opponent_position, attack_type)
    # If unit has not such kind of attack
    # return false
    return false unless @unit_prototype[attack_type]
    # Calculate distance
    attack_range = @unit_prototype["#{attack_type}_range".to_sym]
    distantion = opponent_position + @position
    return distantion > (1.0 - attack_range) # and distantion < 1.0
  end

  def in_attack_range?(opponent, attack_type)
    # If unit has not such kind of attack
    # return false
    return false unless @unit_prototype[attack_type]
    # 

    # unless opponent.static?
    #   return false unless opponent.path_id == @path_id
    # end

    # Calculate distance
    attack_range = @unit_prototype["#{attack_type}_range".to_sym]
    body_width = opponent.body_width
    distantion = opponent.position + @position

    return ((distantion + attack_range) > 1.0 - body_width) && (distantion < 1.0)
  end

  def attack(opponent_unit, attack_type)
    case attack_type
    when :melee_attack
      opponent_unit.decrease_health_points(@melee_attack_power,
        @unit_prototype[:melee_attack_damage_type])

      @attack_period_time = @unit_prototype[:melee_attack_speed]
      @status = ATTACK_MELEE
    when :range_attack

      opponent_unit.decrease_health_points(@range_attack_power,
        @unit_prototype[:range_attack_damage_type])

      @attack_period_time = @unit_prototype[:range_attack_speed]
      @status = ATTACK_RANGE
    end
  end

  def static?
    false
  end

  def can_attack?
    return (@status == MOVE || @status == IDLE) #|| (@target.nil? || @target.dead?)
  end

  def update(iteration_delta)
    #target out of range?
    # unless @target.nil?
    #   @target = nil if @target.position + @position > 1.1
    # end

    unless @target.nil?

      



      can_attack = @status == MOVE || @status == IDLE

      if can_attack

        [:melee_attack, :range_attack].each do |type|

          if in_attack_range?(@target, type)

            attack(@target, type)

            if @target.static? == false# && @target.target.nil?

              if @target.target != self

                @target.target = self if @target.position + @position > 0.9
              end

              # puts "#{@target.path_id} | #{@path_id}"
            end

            # @health_points = -1
            # @target.health_points = -1

            @target = nil if @target.dead?

          end
        end
      end
    end


    case @status
    when MOVE
      if @position < 0.9
        @position += iteration_delta * @movement_speed
      else
        @status = IDLE
      end


    when ATTACK_MELEE, ATTACK_RANGE
      @attack_period_time -= iteration_delta
      @status = IDLE if @attack_period_time < 0
    when IDLE
      @status = MOVE

    end
    @status = DIE if @health_points < 0.0
    # Processing sync
    has_changes = @force_sync
    unless @status == IDLE
      has_changes = @status != @prev_status
      @prev_status = @status
    end
    has_changes = true if @force_sync
    @force_sync = false

    return has_changes
  end
end