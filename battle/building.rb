module Battle
  class BattleBuilding

    @@uid_iteratior = 0

    if ENV['DEBUG']
      HEALTH_POINTS = 10
    else
      HEALTH_POINTS = 400
    end

    BODY_WIDTH = 0.05

    attr_accessor :uid, :health_points, :position, :target
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
      @distance_attack_sync_info = []

      @target = nil
    end

    def path_id
      @engaged_routes.sample
    end

    def at_same_path? path_id
      @engaged_routes.include? path_id
    end

    def has_no_target?
      @target.nil?
    end

    def add_distance_attack_sync_info opponent_unit_uid
      @distance_attack_sync_info << opponent_unit_uid
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

    def sync_data
      data = [@uid, @health_points, @distance_attack_sync_info]
      @distance_attack_sync_info = []

      data
    end

    def decrease_health_points decrease_by
      @health_points -= decrease_by
      @force_sync = true
    end

    def update(iteration_delta)
    end
  end
end