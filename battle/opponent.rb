class Opponen
  attr_accessor :id, :main_building, :path_ways
  attr_reader :spawned_units_count

  TARGETING_OFFSET = 0.6
  BETWEEN_COUNT_OFFSET = 1

  def initialize(data, connection = nil)
    @id = data[:id]
    # Units data, available and lost
    @units = {}
    data[:units].each do |uid, count|
      @units[uid] = {
        :available => count,
        :lost => 0
      }
    end

    @ready = false
    @main_building = BattleBuilding.new( 'building_1', 0.05 )

    @connection = connection

    @ai = false
    if @connection.nil?
      @ai = true
      @ready = true
    end

    @path_ways = []
    PATH_COUNT.times do
      @path_ways << []
    end

    @spawned_units_count = 0
  end

  def lose?
    @main_building.dead?
  end

  def finish_battle!(loser_id)
    # Sync player data, if not AI
    unless @ai
      player = PlayerFactory.instance.player(@id)
      player.unfreeze!
      player.sync_after_battle({
        :units => @units
      })
      # Notificate about battle ended
      @connection.send_finish_battle(loser_id)

      @path_ways.each do |path|
        path.each_with_index do |unit, index|
          path[index].target = nil
          path[index] = nil
        end
      end

      @path_ways = nil
    end
  end

  def sort_units!
    @path_ways.each do |path_way|
      path_way.sort_by!{|v| v.position}.reverse!
    end
  end

  def send_game_data!(shared_data)
    unless @connection.nil?
      @connection.send_create_new_battle_on_client( @id, @units, shared_data )
    end
  end

  def send_spell_cast!(spell_uid, timing, horizontal_target, opponent_uid, area)
    unless @connection.nil?
      @connection.send_spell_cast(
        spell_uid, timing, horizontal_target, opponent_uid, area
      )
    end
  end

  def send_custom_event!(event_name, data_array = [])
    unless @connection.nil?
      @connection.send_custom_event( event_name, data_array )
    end
  end

  def send_sync_data!(sync_data)
    unless @connection.nil?
      @connection.send_battle_sync( sync_data )
    end
  end

  def update(opponent, iteration_delta)
    # First need to sort opponent units by distance
    opponent.sort_units!

    sync_data_arr = []

    @path_ways.each_with_index do |path, index|
      path.each do |unit|
        next if unit.dead?

        if unit.has_no_target? && unit.can_attack?
          target = find_target!(unit, opponent)
          unless target.nil?

            unit.target = target
            unless target.static?
              unit.path_id = target.path_id
              unit.force_sync = true
            end

            @path_ways[unit.path_id] << @path_ways[index].delete(unit)
          end
        end

      end
    end

    @path_ways.each_with_index do |path, index|
      path.each do |unit|

        if unit.update(iteration_delta)
          sync_data_arr << unit.sync_data
        end

        unit.target = nil if unit.target_leave_path?

        if unit.dead?
          # Iterate lost unit counter
          unit_data = @units[unit.name]
          unless unit_data.nil?
            unit_data[:lost] += 1
          end
          path.delete(unit)
          @spawned_units_count -= 1
        end
      end
    end

    # Main building - is a main game trigger.
    # If it is destroyed - player loses
    # Send main bulding updates only if has changes
    if @main_building.changed?
      sync_data_arr << [main_building.uid, main_building.health_points]
    end

    return sync_data_arr
  end

  def ready!
    @ready = true
  end

  def ready?
    @ready = true
  end

  def start_battle!
    @connection.send_start_battle() unless @connection.nil?
  end

  def add_unit_to_pool(unit_name, validate)
    valid = !validate

    if validate
      unit_data = @units[unit_name]
      if !unit_data.nil? and unit_data[:available] > 0
        unit_data[:available] -= 1
        valid = true
      end
    end

    if valid
      unit = BattleUnit.new(unit_name)
      unit.path_id = rand(0..PATH_COUNT-1)
      @path_ways[unit.path_id] << unit


      @spawned_units_count += 1

      return unit
    end

    return nil
  end

  def send_unit_spawn!(unit_uid, unit_name, player_id, path_id)
    @connection.send_unit_spawning(
      unit_uid, unit_name, player_id, path_id
    ) unless @connection.nil?
  end

  def destroy!
    @connection = nil
    @path_ways.each_with_index do |path, index|
      path.each do |unit|
        unit.target = nil
        unit = nil
      end
    end
    @main_building = nil
  end

  private
  def find_nearest(attaker, opponent_path_ways)
    closest_distance = -1.0
    target = nil
    attaker_position = attaker.position
    attaker_path_id = attaker.path_id

    opponent_path_ways.each_with_index do |path_way, index|

      targets = path_way.select {|unit| (unit.position + attaker_position) < 1.0}

      unless targets.empty?
        nearest = targets[0]
        nearest_position = nearest.position
        distance = nearest_position + attaker_position

        next if distance > 1.0
        next if distance < TARGETING_OFFSET

        target_mirrored_position = 1.0 - nearest_position

        attack_offset = (attaker.attack_offset + nearest.attack_offset)
        # time
        inverted_dist = (1.0 - distance) + attack_offset
        horizontal_time = inverted_dist + 0.05 / ((attaker.movement_speed  + nearest.movement_speed))
        vertical_time = (attaker_path_id - index).abs * 0.2
        next if vertical_time > horizontal_time

        count_between = @path_ways[index].select {|u|
          # u.position > attaker_position && u.position < target_mirrored_position
          u.position.between?(attaker_position, target_mirrored_position)
        }.length

        next if count_between > BETWEEN_COUNT_OFFSET

        if (distance > closest_distance)
          closest_distance = distance
          target = nearest
        end
      end
    end

    target
  end

  def find_target!(attaker, opponent)
    target = nil

    [:melee_attack, :range_attack].each do |type|
      if attaker.in_attack_range?(opponent.main_building, type)
        target = opponent.main_building
      end
    end

    target = find_nearest(attaker, opponent.path_ways) if target.nil?

    target
  end

end