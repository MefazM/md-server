module Battle
  class BattleBuilding

    @@uid_iteratior = 0

    HEALTH_POINTS = 200
    BODY_WIDTH = 0.05

    attr_accessor :uid, :health_points, :position
    attr_reader :body_width, :engaged_routes

    def initialize(name, position)
      @name = name
      @uid = "b#{@@uid_iteratior}"
      @@uid_iteratior += 1
      # additional params
      @position = position
      @health_points = HEALTH_POINTS

      @force_sync = false

      @body_width = 1.0 - BODY_WIDTH

      @engaged_routes = [9,8,6,7]
    end

    def path_id
      @engaged_routes.sample
    end

    def static?
      true
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