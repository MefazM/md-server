module Battle
  class BattleUnit
    @@uid_iteratior = 0
    # Unit states
    MOVE = 1
    DIE = 3
    ATTACK_MELEE = 4
    ATTACK_RANGE = 5
    IDLE = 42
    # "spell-based" states
    STUNED = 101
    #
    NO_TARGET = -1
    MAX_POSITION = 0.9

    attr_accessor :uid, :position, :status, :name,
      :movement_speed, :force_sync, :range_attack_power,
      :melee_attack_power, :target, :path_id, :health_points

    attr_reader :unit_prototype, :body_width, :attack_offset

    def initialize(unit_uid, position = 0.0)
      @name = unit_uid.to_sym
      # initialization unit by prototype
      @unit_prototype = Storage::GameData.unit @name

      @uid = "u#{@@uid_iteratior}"
      @@uid_iteratior += 1
      # additional params
      @status = IDLE
      @prev_status = IDLE
      @attack_period_time = 0
      @position = position

      @range_attack_power = attack_power :range_attack
      @melee_attack_power = attack_power :melee_attack

      @health_points = @unit_prototype[:health_points]
      @movement_speed = @unit_prototype[:movement_speed]
      @attack_type = nil

      @force_sync = false

      @body_width = 1.0 - 0.015

      @target = nil

      @attack_offset = @unit_prototype[:melee_attack][:range]

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

    def dead?
      @health_points < 0.0
    end

    def low_hp? scale
      @health_points.to_f < @unit_prototype[:health_points].to_f * scale
    end

    def sync_data
      hp_scale = @health_points.to_f / @unit_prototype[:health_points].to_f
      data = [@uid, @status, @path_id, @position.round(3), hp_scale]

  # puts("#{@uid} #{position} ")
      target = has_no_target? ? NO_TARGET : @target.uid

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

    def decrease_health_points(decrease_by, attack_type = nil)
      # TODO: Implement resists
      resist_type = @unit_prototype[:resist_type]
      decrease_by *= 0.5 if resist_type and attack_type == resist_type
      @health_points -= decrease_by
      @force_sync = true
      # return hp
      @health_points
    end

    def increase_health_points(increase_by)
      @health_points = [@unit_prototype[:health_points], @health_points + increase_by].min
      @force_sync = true
    end

    def in_attack_range?(target, attack_type)
      # If unit has not such kind of attack
      # return false
      return false unless @unit_prototype[attack_type]
      # Calculate distance
      attack_range = @unit_prototype[attack_type][:range]
      distantion = target.position + @position

      return ((distantion + attack_range) > target.body_width) && (distantion < 1.0)
    end

    def attack(target, attack_type)
      case attack_type
      when :melee_attack
        target.decrease_health_points(@melee_attack_power,
          @unit_prototype[:melee_attack][:type])

        @attack_period_time = @unit_prototype[:melee_attack][:speed]
        @status = ATTACK_MELEE
      when :range_attack

        target.decrease_health_points(@range_attack_power,
          @unit_prototype[:range_attack][:type])

        @attack_period_time = @unit_prototype[:range_attack][:speed]
        @status = ATTACK_RANGE
      end
    end

    def static?
      false
    end

    def can_attack?
      (@status == MOVE || @status == IDLE)
    end

    def update(iteration_delta)

      if can_attack? && !has_no_target?
        [:melee_attack, :range_attack].each do |type|
          if in_attack_range?(@target, type)
            attack(@target, type)

            if @target.static? == false && @target.target != self
              @target.target = self if @target.position + @position > 0.9
            end
            if @target.dead?
              @target = nil
              break
            end
          end
        end
      end

      case @status
      when MOVE
        if @position < MAX_POSITION
          @position += iteration_delta * @movement_speed
        else
          @status = IDLE
        end
      when ATTACK_MELEE, ATTACK_RANGE
        @attack_period_time -= iteration_delta
        @status = IDLE if @attack_period_time < 0
      when IDLE
        @status = MOVE if @position < MAX_POSITION
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

    def attack_power attack_type

      return nil if @unit_prototype[attack_type].nil?

      min = @unit_prototype[attack_type][:power_min]
      max = @unit_prototype[attack_type][:power_max]

      rand(min..max)
    end

  end
end