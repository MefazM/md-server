module Player
  module BuildingsProduction
    def add_update_building_task(building_uid, construction_time, level)
      @buildings_queue[building_uid] = {
        :finish_at => construction_time + Time.now.to_f,
        :construction_time => construction_time,
        :level => level
      }
    end

    def building_ready? uid
      !@buildings_queue[uid].nil?
    end

    def process_buildings_queue current_time
      @buildings_queue.each do |building_uid, task|
        if task[:finish_at] < current_time
          @buildings_queue.delete(building_uid)
          # Each building stores in uid:level pair.
          # @buildings[building_uid].nil? - means that building has 0 level
          if @buildings[building_uid].nil?
            @buildings[building_uid] = 1
          else
            # After update - increase building level
            @buildings[building_uid] += 1
          end

          send_sync_building_state(building_uid, @buildings[building_uid])
        end

      end
    end

    def buildings_updates_queue_export
      queue = {}
      unless @buildings_queue.empty?
        current_time = Time.now.to_f
        @buildings_queue.each do |building_uid, task|
          task_info = {
            :finish_time => (task[:finish_at] - current_time) * 1000,
            :production_time => task[:construction_time] * 1000,
            :level => task[:level],
            :uid => building_uid
          }

          queue[building_uid] = task_info
        end
      end

      queue
    end

  end
end