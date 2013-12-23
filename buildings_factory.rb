class BuildingsFactory
  include Singleton
  # Load buildings from DB
  def initialize()
    MageLogger.instance.info "BuildingsFactory| Loading buildings from DB ..."
    @buildings_prototypes = {}
    sql = "SELECT * FROM buildings"
    building = DBConnection.query(sql).each do |building|
      uid = building[:uid]
      level = building[:level]

      @buildings_prototypes[uid] = {} if @buildings_prototypes[uid].nil?
      @buildings_prototypes[uid][level] = building
    end
    # buildings production tasks
    @buildings_productions_tasks = {}
    MageLogger.instance.info "BuildingsFactory| #{@buildings_prototypes.count} building(s) - loaded."
  end

  def add_production_task(player_id, uid)
    current_time = Time.now.to_f

    player = PlayerFactory.get_player_by_id(player_id)
    # if player already construct this building, current_level > 0
    current_level = player.get_building_level(uid)

    next_level_building = current_level + 1

    building_to_construct = @buildings_prototypes[uid][next_level_building]
    # return false if no building at this level
    if building_to_construct.nil?
      MageLogger.instance.info "BuildingsFactory| Building not found! uid = #{uid}, level = #{update_level}"
      return false
    end

    @buildings_productions_tasks[player_id] = [] if @buildings_productions_tasks[player_id].nil?
    production_time = 5#building_to_construct[:production_time]
    # check player can add task
    # price = @buildings_prototypes[uid][current_level].price
    # player.has_resources? price
    # player.decrease_resourse price
    @buildings_productions_tasks[player_id] << {
      :finish_at => production_time + current_time,
      :production_time => production_time,
      :uid => uid,
      :level => next_level_building,
      # :price => price
    }
    # Notify client about task start
    connection = PlayerFactory.connection(player_id)
    # Convert to client ms
    production_time_in_ms = production_time * 1000
    unless connection.nil?
      connection.send_sync_building_state(uid, next_level_building, false, production_time_in_ms)
    end

  end
  # Buildings in queue
  def buildings_in_queue player_id
    queue = {}
    player_queue = @buildings_productions_tasks[player_id]

    unless player_queue.nil?
      current_time = Time.now.to_f
      @buildings_productions_tasks[player_id].each do |task|
        task_uid = task[:uid]
        task_info = {
          :level => task[:level],
          :uid => task_uid,
          :finish_time => (task[:finish_at] - current_time) * 1000,
          :production_time => task[:production_time] * 1000
        }

        queue[task_uid] = task_info
      end
    end

    queue
  end

  def update_production_tasks current_time
    @buildings_productions_tasks.each do |player_id, tasks|
      tasks.each_with_index do |task, index|
        if task[:finish_at] < current_time
          player = PlayerFactory.get_player_by_id(player_id)
          player.add_or_update_building(task[:uid], task[:level])
          # Notify client about task finished
          connection = PlayerFactory.connection(player_id)
          unless connection.nil?
            connection.send_sync_building_state(task[:uid], task[:level], true)
          end
          # Destroy task
          tasks.delete_at(index)
          # Destroy player queue if no tasks left.
          @buildings_productions_tasks.delete(player_id) if tasks.empty?
        end
      end
    end
  end

end
