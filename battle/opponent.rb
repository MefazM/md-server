class Opponen
  attr_accessor :id, :main_building, :units_pool, :path_ways, :main_building_attaker

  PATH_COUNT = 10

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
    @units_pool = []
    @main_building = BattleBuilding.new( 'building_1', 0.05 )

    @connection = connection

    @ai = false
    if @connection.nil?
      @ai = true
      @ready = true
    end

    @target_unit_id_counter = 0

    @each_path_units = []

    11.times do |i|
      @each_path_units[i] = 0
    end

    @path_ways = []
    PATH_COUNT.times do
      @path_ways << []
    end

    @main_building_attaker = []

    @units_count = 0
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
    end
  end

  def sort_units!

    @path_ways.each do |path_way|
      path_way.sort_by!{|v| v.position}.reverse!
    end

    # @units_pool.sort_by!{|v| v.position}.reverse!
  end

  def send_game_data!(shared_data)
    unless @connection.nil?
      @connection.send_create_new_battle_on_client( @id, @units, shared_data )
    end
  end

  def send_spell_cast!(spell_uid, timing, target_area, opponent_uid, area)
    unless @connection.nil?
      @connection.send_spell_cast(
        spell_uid, timing, target_area, opponent_uid, area
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

  def find_targets_at_line(attaker_position, path_way)
    path_way.select {|unit| (unit.position + attaker_position) < 1.0}
  end

  def find_nearest(attaker, opponent_path_ways)
    position = -1.0
    target = nil
    attaker_position = attaker.position
    attaker_path_id = attaker.path_id

    near_spawn = attaker_position < 0.15


    opponent_path_ways.each_with_index do |path_way, index|

      # next if @path_ways[index].length > 5

      # count = @path_ways[index].select {|u| u.position > attaker_position}.length
      # next if count > 2# && !near_spawn

#       binding.pry if @path_ways[index].length > 5
# puts("#{count}, #{index}")
      nearest_targets = find_targets_at_line(attaker_position, path_way)
      unless nearest_targets.empty?

        # next if near_spawn == false && attaker_path_id == index

        nearest_target = nearest_targets[0]
        nearest_target_position = nearest_target.position + attaker_position


        next if (nearest_target_position + attaker_position) < 0.8

        # allow_overflow_cross = near_spawn && (nearest_target_position + attaker_position > 0.75)

        # max_count = allow_overflow_cross ? 8 : 3

        # count = @path_ways[index].select {|u| u.position > attaker_position && u.position < (1.0 - nearest_target_position)}.length

        # @path_ways[index].select {|u| u.position > attaker_position && u.position < (1.0 - nearest_target_position)}.length
    # unless nearest_target_position > 0.75
      count_all = 0
      count_between = 0

      @path_ways[index].each do |u|

        if (u.position > attaker_position && u.position < (1.0 - nearest_target.position))
          count_between +=1
        end

        if  (u.position > attaker_position)
          count_all +=1
        end

      end

      # next if count_between >= nearest_targets.length || @path_ways[index].length > 2 #&& !near_spawn
      next if count_between > 1
    # end

        # puts(count_between, @path_ways[index].length)



        if (nearest_target_position > position) #&& count > 3


          position = nearest_target_position
          target = nearest_target

        end
      end
    end

    target
  end

  def find_this_fucking_target!(attaker, opponent)
    target = nil

    [:melee_attack, :range_attack].each do |type|
      if attaker.in_attack_range?(opponent.main_building, type)
        target = opponent.main_building
      end
    end

    if target.nil?
      target = find_nearest(
        attaker,
        opponent.path_ways
      )
    end

    attaker.target = target

    unless target.nil? || target.static?

      # if target.target.nil?
      #   target.target = attaker
      # end

      return target.path_id
    else

      return nil
    end
  end

  def update(opponent, iteration_delta)
    # puts("UC: #{@units_count}")
    # First need to sort opponent units by distance
    opponent.sort_units!

    sync_data_arr = []

    @path_ways.each_with_index do |path, index|
      path.each do |unit|
        next if unit.nil?

        if unit.has_no_target?
          new_path_id = find_this_fucking_target!(unit, opponent)
          unless new_path_id.nil?
            unit.path_id = new_path_id
            unit.force_sync = true
            @path_ways[new_path_id] << @path_ways[index].delete(unit)


          end
        end
        # Make unit follow the target
        binding.pry if unit.position > 0.98

      end
    end

    @path_ways.each_with_index do |path, index|
      path.each do |unit|

        # next if unit.dead?
        next if unit.nil?

        if unit.update(iteration_delta)
          sync_data_arr << unit.sync_data
        end

        if unit.target_leave_path?
          unit.target = nil
          # old_index = unit.path_id
          # new_index = unit.target.path_id

          # unit.path_id = new_index
          # unit.force_sync = true
          # @path_ways[new_index] << @path_ways[old_index].delete(unit)
        end


        if unit.dead?
          # Iterate lost unit counter
          unit_data = @units[unit.name]
          unless unit_data.nil?
            unit_data[:lost] += 1
          end
          path.delete(unit)
          @units_count -= 1
          # unit = nil
        end
      end
    end

    # Main building - is a main game trigger.
    # If it is destroyed - player loses
    # main_building = player[:main_building]
    @main_building.update(iteration_delta)
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
      # Set new unit target from those who attacks a main building

      unit.path_id = rand(0..PATH_COUNT-1)


      @path_ways[unit.path_id] << unit

      @units_count += 1

      return unit
    end

    return nil
  end

  def notificate_unit_spawn!(unit_uid, unit_name, player_id, path_id)
    @connection.send_unit_spawning(
      unit_uid, unit_name, player_id, path_id
    ) unless @connection.nil?
  end

  def destroy!
    @connection = nil
  end

  private

end