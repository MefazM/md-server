module Battle
  class Opponen

    TARGETING_OFFSET = 0.6
    BETWEEN_COUNT_OFFSET = 1

    attr_reader :spawned_units_count, :units_statistics, :path_ways,
                :ai, :id, :main_building, :mana_data, :spells_statistics,
                :username, :level

    def initialize data
      @id = data[:id]
      # Units data, available and lost
      @units_statistics = {}
      data[:units].each do |uid, count|
        @units_statistics[uid] = {
          :available => count,
          :lost => 0
        }
      end
      # Ai opponent is ready to battle by default
      @ready = ai
      @ai = data[:is_ai] || false
      # HACK!!!!!
      @mana_data = {}
      if @ai == false
        @mana_data = {
          :value => data[:mana][0],
          :capacity => data[:mana][1],
          :amount => data[:mana][2]
        }
      end

      @main_building = BattleBuilding.new( 'building_1', 0.05 )
      #
      @path_ways = []
      PATH_COUNT.times do
        @path_ways << []
      end
      @spawned_units_count = 0

      @spells_statistics = []

      @username = data[:username]
      @level = data[:level]
    end

    def statistics
      {
        :units => @units_statistics,
        :spells => @spells_statistics,
        :level => @level,
        :username => @username
      }
    end

    def units_at_front segment_length = 15
      positions = {} #Hash.new(0)

      units = @path_ways.flatten
      units.each do |unit|

        segment = ((unit.position / segment_length) * 100).to_i

        positions["k_#{segment}"] ||= {
          :count => 0,
          :pos => 0.0
        }

        if block_given?
          if yield(unit)
            positions["k_#{segment}"][:count] += 1
            positions["k_#{segment}"][:pos] += unit.position
          end
        else
          positions["k_#{segment}"][:count] += 1
          positions["k_#{segment}"][:pos] += unit.position
        end
      end

      matched, matches = positions.max_by{|_,u| u[:count]}

      return nil if matched.nil?

      avg_pos = matches[:pos] / matches[:count].to_f

      return avg_pos, matches[:count]
    end

    def track_spell_statistics uid
      @spells_statistics << uid
    end

    def lose?
      @main_building.dead?
    end

    def sort_units!
      @path_ways.each do |path_way|
        path_way.sort_by!{|v| v.position}.reverse!
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
              @path_ways[unit.path_id] << @path_ways[index].delete(unit)

              if target.has_no_target?
                target.target = unit
              end
            end
          end

        end
      end

      @path_ways.each_with_index do |path, index|
        path.each do |unit|
          if unit.update(iteration_delta)
            sync_data_arr << unit.sync_data
          end
          if unit.dead?
            # Iterate lost unit counter
            unit_data = @units_statistics[unit.name]
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
        sync_data_arr << main_building.sync_data
      end

      return sync_data_arr
    end

    def ready!
      @ready = true
    end

    def ready?
      @ready
    end

    def add_unit_to_pool(unit_name, validate = true)
      valid = !validate
      if validate
        unit_data = @units_statistics[unit_name]
        if !unit_data.nil? and unit_data[:available] > 0
          unit_data[:available] -= 1
          valid = true
        end
      end

      if valid
        unit = BattleUnit.new(unit_name, rand(0..PATH_COUNT-1))
        @path_ways[unit.path_id] << unit
        @spawned_units_count += 1
        return unit
      end

      return nil
    end

    def destroy!
      @main_building = nil
      @path_ways.each do |path|
        path.each do |unit|
          unit.target = nil
          unit = nil
        end
      end

      @path_ways = nil
    end

    private

    def find_nearest(attaker, opponent_path_ways)
      closest_distance = -1.0
      target = nil
      attaker_position = attaker.position
      attaker_path_id = attaker.path_id

      target_min_path_way = attaker_path_id - 2

      target_min_path_way = 0 if target_min_path_way < 0

      target_max_path_way = attaker_path_id + 2
      target_max_path_way = 9 if target_max_path_way > 9

      # opponent_path_ways[target_min_path_way..target_max_path_way].each_with_index do |path_way, index|
      opponent_path_ways.each_with_index do |path_way, index|

      # puts("I: #{attaker_path_id} | MIN: #{target_min_path_way} | MAX: #{target_max_path_way}")

        targets = path_way.select {|unit| (unit.position + attaker_position) < 1.0}

        unless targets.empty?
          nearest = targets[0]
          nearest_position = nearest.position

          next if nearest_position < 0.06

          distance = nearest_position + attaker_position

          next if distance > 1.0
          next if distance < TARGETING_OFFSET

          target_mirrored_position = 1.0 - nearest_position

          attack_offset = (attaker.attack_offset + nearest.attack_offset)
          # time
          inverted_dist = (1.0 - distance) + attack_offset
          horizontal_time = inverted_dist + 0.05 / ((attaker.movement_speed  + nearest.movement_speed))
          vertical_time = (attaker_path_id - index).abs * 0.2
          #next if vertical_time > horizontal_time

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
          return target
        end
      end

      target = find_nearest(attaker, opponent.path_ways) if target.nil?

      target
    end

  end
end