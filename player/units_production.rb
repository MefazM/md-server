module Player
  module UnitsProduction
    def units_in_queue_export
      current_time = Time.now.to_f
      queue = {}
      unless @units_production_queue.empty?
        @units_production_queue.each do |group_uid, group|
          queue[group_uid] = []

          group.each do |unit_uid, task|
            task_info = {
              :uid => unit_uid,
              :count => task[:count],
              :production_time => task[:construction_time]
            }

            if task[:started_at]
              # task_info[:started_at] = (( task[:finish_at] - current_time ) * 1000 ).to_i
              task_info[:started_at] = (task[:started_at] * 1000 ).to_i
            end
            # Collect task
            queue[group_uid] << task_info
          end
        end
      end

      queue
    end

    def add_unit_production_task(unit_uid, construction_time, group_by)
      @units_production_queue[group_by] = {} if @units_production_queue[group_by].nil?
      # If player has no tasks from grop create it
      if @units_production_queue[group_by][unit_uid].nil?
        @units_production_queue[group_by][unit_uid] = {
          :count => 1,
          :construction_time => construction_time
        }
      else
        # Increase tasks number if such tasks exist in queue
        @units_production_queue[group_by][unit_uid][:count] += 1
      end
    end

    def process_unit_queue current_time
      @units_production_queue.each do |group_uid, group|
        unit_uid, current_task = group.first
        if current_task.nil?
          # queue is empty for this group
          @units_production_queue.delete(group_uid)
        else
          if current_task[:finish_at].nil?
            construction_time = current_task[:construction_time]
            current_task[:finish_at] = current_time + construction_time
            current_task[:started_at] = current_time

            construction_time_in_ms = construction_time * 1000
            send_start_unit_queue_task(group_uid, construction_time_in_ms)
          else
            if current_task[:finish_at] < current_time
              current_task[:finish_at] = nil
              tasks_left = current_task[:count] -= 1

              group.delete(unit_uid) if tasks_left == 0

              units_count = @units[unit_uid] || 0
              @units[unit_uid] = units_count + 1
            end
          end
        end

      end
    end

  end
end