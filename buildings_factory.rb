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

  def price uid, level
    @buildings_prototypes[uid][level][:price]
  end

  def add_production_task(player_id, uid, level_building)
    current_time = Time.now.to_f
    # # if player already construct this building, current_level > 0
    building_to_construct = @buildings_prototypes[uid][level_building]
    # return false if no building at this level
    if building_to_construct.nil?
      MageLogger.instance.info "BuildingsFactory| Building not found! uid = #{uid}, level = #{update_level}"
      return false
    end

    @buildings_productions_tasks[player_id] = [] if @buildings_productions_tasks[player_id].nil?
    production_time = building_to_construct[:production_time]
    # check player can add task
    # price = @buildings_prototypes[uid][current_level].price
    # player.has_resources? price
    # player.decrease_resourse price
    task_data = {
      :finish_at => production_time + current_time,
      :production_time => production_time,
      :uid => uid,
      :level => level_building,
      # :price => price
    }

    @buildings_productions_tasks[player_id] << task_data
    # Notify client about task start
    # connection = PlayerFactory.instance.connection(player_id)
    # # Convert to client ms
    # production_time_in_ms = production_time * 1000
    # unless connection.nil?
    #   connection.send_sync_building_state(uid, next_level_building, false, production_time_in_ms)
    # end
    task_data
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

          PlayerFactory.instance.update_building(player_id, task[:uid], task[:level])

          # Destroy task
          tasks.delete_at(index)
          # Destroy player queue if no tasks left.
          @buildings_productions_tasks.delete(player_id) if tasks.empty?
        end
      end
    end
  end

end
