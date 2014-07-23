require "battle/unit_spells_effect"
module Battle
  class BattleUnit

    include UnitSpellsEffect

    @@uid_iteratior = 0
    # Unit states
    MOVE = 1
    DIE = 3
    ATTACK_MELEE = 4
    ATTACK_RANGE = 5
    IDLE = 42
    #
    NO_TARGET = -1
    MAX_POSITION = 0.9

    attr_accessor :uid, :position, :status, :name,
      :movement_speed, :force_sync, :range_attack_power,
      :melee_attack_power,  :health_points

    attr_reader :unit_prototype, :body_width, :attack_offset, :path_id

    def initialize(unit_uid, path_id, position = 0.0)
      @name = unit_uid.to_sym
      @path_id = path_id
      # initialization unit by prototype
      @unit_prototype = Storage::GameData.unit @name

      @uid = "u#{@@uid_iteratior}"
      @@uid_iteratior += 1
      # additional params
      @status = MOVE
      @prev_status = MOVE
      @attack_period_time = 0
      @position = position

      @range_attack_power = attack_power :range_attack
      @melee_attack_power = attack_power :melee_attack

      @health_points = @unit_prototype[:health_points]
      @movement_speed = @unit_prototype[:movement_speed]

      @force_sync = true
      @body_width = 1.0 - 0.015
      @target = nil
      @attack_offset = @unit_prototype[:melee_attack][:range]

      @affected_spells = {}
    end

    def at_same_path? path_id
      @path_id == path_id
    end

    def has_no_target?
      unless @target.nil?
        @target = nil if @target.position + @position > 1.0
      end

      unless @target.nil? || @target.at_same_path?(@path_id)
        @target = nil
      end

      @target.nil? || @target.dead?
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

      data << has_no_target? ? NO_TARGET : @target.uid

      animation_scale = case @status
      when MOVE
        @movement_speed / @unit_prototype[:movement_speed]
      else
        1.0
      end

      data << animation_scale

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

    def can_attack?
      @status == MOVE
    end

    def target= target
      @target = target
      unless target.nil?
        @path_id = target.path_id
        @force_sync = true
      end
    end

    def update(iteration_delta)

      @status = DIE if @health_points < 0.0

      has_changes = @status != @prev_status
      @prev_status = @status

      if can_attack? && !has_no_target?
        [:melee_attack, :range_attack].each do |type|
          if in_attack_range?(@target, type)
            attack(@target, type)
          end
        end
      end

      case @status
      when MOVE

        @position += iteration_delta * @movement_speed if @position < MAX_POSITION

      when ATTACK_MELEE, ATTACK_RANGE
        @attack_period_time -= iteration_delta
        @status = MOVE if @attack_period_time < 0
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