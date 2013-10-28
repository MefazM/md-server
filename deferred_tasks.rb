require 'singleton'

require_relative 'db_connection.rb'
require_relative 'mage_logger.rb'
require_relative 'player_factory.rb'

class DeferredTasks
  include Singleton

  def initialize
    @iteration_time = Time.now.to_f
    @current_tasks_ids = []
  end

  def add(player_owner_id, resource_id, resource_type, production_time = 20)
    DBConnection.query(
      "INSERT INTO deferred_tasks (user_id, resource_id, resource_type, finish_time) VALUES (#{player_owner_id}, '#{resource_id}', '#{resource_type}',  UNIX_TIMESTAMP() + #{production_time})"
    )
  end

  def add_task_with_sequence(player_owner_id, resource_id, resource_type, production_time, producer_id)
    DBConnection.query(
      "INSERT INTO deferred_tasks_with_sequences (player_id, resource_id, resource_type, production_time, producer_id) VALUES (#{player_owner_id}, '#{resource_id}', '#{resource_type}',  '#{production_time}', '#{producer_id}')"
    )
  end

  def process_all(current_time)
    process_tasks_with_sequences(current_time)
  end

  def process_tasks_with_sequences(current_time)
    d_time = current_time - @iteration_time
    if d_time > Timings::DEFERRED_TASKS_PROCESS_TIME
      @iteration_time = current_time

      sql = 'SELECT id FROM deferred_tasks_with_sequences GROUP BY producer_id'

      cur_tasks_ids = []

      DBConnection.query(sql).each do |task|
        cur_tasks_ids << task[:id]
      end

      unless cur_tasks_ids.empty?

        sql = "UPDATE deferred_tasks_with_sequences SET production_time = production_time - '#{d_time}' WHERE id IN(#{cur_tasks_ids.join(',')})"
        DBConnection.query(sql)

        tasks_to_delete = []

        sql = 'SELECT * FROM deferred_tasks_with_sequences WHERE production_time <= 0'
        DBConnection.query(sql).each do |task|

          player = PlayerFactory.get_player_by_id(task[:player_id])

          player.add_unit(task[:resource_id])

          tasks_to_delete << task[:id]
        end

        unless tasks_to_delete.empty?

          sql = "DELETE FROM deferred_tasks_with_sequences WHERE id IN ( #{tasks_to_delete.join(',')} )"
          DBConnection.query(sql)
        end
      end
    end
  end

private

  def process_task(task)

  end

  # def process_tasks_with_no_sequences(current_time)

  #   if current_time - @@iteration_time > Timings::DEFERRED_TASKS_PROCESS_TIME
  #     @@iteration_time = current_time

  #     sql = 'SELECT * FROM deferred_tasks WHERE UNIX_TIMESTAMP() > finish_time'

  #     tasks_to_delete = []

  #     DBConnection.query(sql).each do |task|
  #       tasks_to_delete << task[:id]
  #     end

  #     unless tasks_to_delete.empty?

  #       sql = "DELETE FROM deferred_tasks WHERE id IN ( #{tasks_to_delete.join(',')} )"
  #       DBConnection.query(sql)
  #     end
  #   end
  # end

end