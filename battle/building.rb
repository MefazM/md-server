module Battle
  class BattleBuilding

    @@uid_iteratior = 0

    attr_accessor :uid, :health_points, :position
    attr_reader :body_width

    def static?
      true
    end

    def initialize(name, position)
      @name = name
      @uid = "b#{@@uid_iteratior}"
      @@uid_iteratior += 1
      # additional params
      @position = position
      @health_points = 200

      @force_sync = false

      @body_width = 1.0 - 0.05
    end

    def changed?
      changed = @force_sync
      @force_sync = false

      changed
    end

    def dead?()
      @health_points < 0
    end

    def export
      [@uid, @uid, @position, @health_points]
    end

    def decrease_health_points(decrease_by, attack_type)
      # Сила аттаки уменьшается в двое, если юнит имеет защиту от такого типа атак.
      @health_points -= decrease_by
      @force_sync = true
    end

    def update(iteration_delta)
    end
  end
end