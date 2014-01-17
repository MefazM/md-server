class UnitsFactory
  include Singleton
  # Load units from database to hash.
  # Unit u#{unit_id} - is a hask key
  def initialize()
    MageLogger.instance.info "UnitsFactory| Loading units from DB ..."
    @units_prototypes = {}
    begin
      DBConnection.query("SELECT * FROM units").each do |unit|
        # Convert attack speed in ms to server seconds
        unit[:melee_attack_speed] *= 0.001 if unit[:melee_attack_speed]
        unit[:range_attack_speed] *= 0.001 if unit[:range_attack_speed]
        @units_prototypes[unit[:uid].to_sym] = unit
      end
    rescue Exception => e
      raise e
    end
    # Hash hold units to produce
    @units_productions_tasks = {}
    MageLogger.instance.info "UnitsFactory| #{@units_prototypes.count} unit(s) - loaded."
  end
  # Get units in queue by player id
  def units_in_queue(player_id)
    current_time = Time.now.to_f
    queue = {}
    unless @units_productions_tasks[player_id].nil?
      @units_productions_tasks[player_id].each do |producer_id, producer|
        queue[producer_id] = []

        producer[:tasks].each do |uid, task|
          task_info = {
            :uid => uid,
            :count => task[:count],
            :production_time => task[:production_time]
          }

          if task[:started_at]
            task_info[:started_at] = (( task[:finish_at] - current_time ) * 1000 ).to_i
          end
          # Collect task
          queue[producer_id] << task_info
        end
      end
    end

    queue
  end
  # Create new unit production task
  def add_production_task(player_id, unit_uid)
    producer_id = @units_prototypes[unit_uid.to_sym][:depends_on_building_uid]
    production_time = @units_prototypes[unit_uid.to_sym][:production_time]
    # If player has no production tasks create it
    @units_productions_tasks[player_id] = {} if @units_productions_tasks[player_id].nil?
    # If player has no producer tasks from producer_id create it
    if @units_productions_tasks[player_id][producer_id].nil?
      # current_task - curent processing task
      # tasks array of tasks grouped by unit uid key
      @units_productions_tasks[player_id][producer_id] = {:current_task => nil, :tasks => {}}
    end
    # Get task by unit uid
    task = @units_productions_tasks[player_id][producer_id][:tasks][unit_uid.to_sym]

    if task.nil?
      # Add new one
      task = { :count => 1, :production_time => production_time }
    else
      # Increase tasks number if such tasks exist in queue
      task[:count] += 1
    end
    # Save tasts queue
    @units_productions_tasks[player_id][producer_id][:tasks][unit_uid.to_sym] = task
    # Responce to client
    connection = PlayerFactory.instance.connection(player_id)
    unless connection.nil?
      connection.send_unit_queue(unit_uid, producer_id, production_time)
    end
  end
  # Tasks processing
  def update_production_tasks current_time
    # Iterate trought all tasks
    @units_productions_tasks.each do |player_id, producers|
      producers.each do |producer_id, producers_tasks|
        # Has current task?
        unless producers_tasks[:current_task].nil?
          # Is task ready?
          if producers_tasks[:current_task][:finish_at] < current_time
            # Free current task
            producers_tasks[:current_task] = nil
            unit_uid, task = producers_tasks[:tasks].first
            task[:count] -= 1

            if task[:count] == 0
              # Empty task queue if this is a last task
              producers_tasks[:tasks].delete(unit_uid)
            end
            # Process complited task
            player = PlayerFactory.instance.get_player_by_id(player_id)
            player.add_unit(unit_uid)

            MageLogger.instance.info "UnitsFactory| Production task finished for player##{player_id}, producer='#{producer_id}', unit added='#{unit_uid}'."
          end
        else
          # Get next tasks if current task is empty
          unit_uid, task = producers_tasks[:tasks].first
          # Start new task if exist
          unless task.nil?
            task[:started_at] = current_time
            task[:finish_at] = current_time + task[:production_time]
            producers_tasks[:current_task] = task
            # Notify client about task start
            connection = PlayerFactory.instance.connection(player_id)
            # Convert to client ms
            production_time_in_ms = task[:production_time] * 1000
            unless connection.nil?
              connection.send_start_task_in_unit_queue(producer_id, production_time_in_ms)
            end
          end
        end
      end
    end
  end
  # Get unit info by uid name
  def units(uid)
    @units_prototypes[uid.to_sym]
  end
end