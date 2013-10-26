require_relative 'db_connection.rb'
require_relative 'mage_logger.rb'

class DeferredTasks
  @@iteration_time = 0

  def self.add(player_owner_id, resource_id, resource_type, period = 20)

    sql = "INSERT INTO deferred_tasks (user_id, resource_id, resource_type, finish_time) VALUES (#{player_owner_id}, '#{resource_id}', '#{resource_type}',  UNIX_TIMESTAMP() + #{period})"

    DBConnection.query(sql)
  end

  def self.process_all(current_time)

    if current_time - @@iteration_time > Timings::DEFERRED_TASKS_PROCESS_TIME
      @@iteration_time = current_time

      sql = 'SELECT * FROM deferred_tasks WHERE UNIX_TIMESTAMP() > finish_time'

      tasks_to_delete = []

      DBConnection.query(sql).each do |task|
        tasks_to_delete << task[:id]
      end

      unless tasks_to_delete.empty?

        sql = "DELETE FROM deferred_tasks WHERE id IN ( #{tasks_to_delete.join(',')} )"
        DBConnection.query(sql)
      end
    end
  end

end