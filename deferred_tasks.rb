require 'singleton'

require_relative 'db_connection.rb'
require_relative 'mage_logger.rb'
require_relative 'player_factory.rb'

class DeferredTasks
  include Singleton

  DEFERRED_TASKS_PROCESS_TIME = 0.1

  def initialize
    @iteration_time = Time.now.to_f
    @current_tasks_ids = []
  end

  def get_tasks_data (player_id)

  end

  def add_task_with_no_sequence(player_id, building)
    resource_id, uid, level, production_time = building[:id], building[:uid], building[:level],  building[:production_time]
    DBConnection.query(
      "INSERT INTO deferred_tasks (user_id, resource_id, finish_time, production_time, uid, level) VALUES (#{player_id}, '#{resource_id}', UNIX_TIMESTAMP() + #{production_time}, #{production_time}, '#{uid}', #{level})"
    )

    DBConnection.last_inser_id
  end

  def add_task_with_sequence(player_id, resource_id, resource_type, production_time, producer_id)
    DBConnection.query(
      "INSERT INTO deferred_tasks_with_sequences (player_id, resource_id, resource_type, production_time, producer_id) VALUES (#{player_id}, '#{resource_id}', '#{resource_type}',  '#{production_time}', '#{producer_id}')"
    )
  end

  def process_all(current_time)
    d_time = current_time - @iteration_time
    if d_time > DEFERRED_TASKS_PROCESS_TIME
      @iteration_time = current_time
      process_tasks_with_no_sequences()
    end
  end

  def get_buildings_in_queue(player_id)
    buildings = {}
    DBConnection.query("SELECT *, (finish_time - UNIX_TIMESTAMP()) AS time_left FROM deferred_tasks WHERE user_id = '#{player_id}'").each do |task|
      buildings[task[:uid]] = {
        :level => task[:level],
        :ready => false,
        :uid => task[:uid],
        :finish_time => task[:time_left] * 1000,
        :production_time => task[:production_time] * 1000
      }
    end

    buildings
  end

private

  def process_tasks_with_sequences(current_time)
    d_time = current_time - @iteration_time
    if d_time > DEFERRED_TASKS_PROCESS_TIME
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

          MageLogger.instance.info "Task ##{task[:id]} is ready."
        end

        unless tasks_to_delete.empty?
          sql = "DELETE FROM deferred_tasks_with_sequences WHERE id IN ( #{tasks_to_delete.join(',')} )"
          DBConnection.query(sql)
        end
      end
    end
  end

  def process_tasks_with_no_sequences()
    sql = 'SELECT * FROM deferred_tasks WHERE UNIX_TIMESTAMP() > finish_time'
    tasks_to_delete = []
    DBConnection.query(sql).each do |task|
      tasks_to_delete << task[:id]

      player = PlayerFactory.get_player_by_id(task[:user_id])
      # player.add_or_update_building(task[:uid], task[:level])

      # response = Respond.as_building(task[:uid], task[:level], true)

      connection = PlayerFactory.connection(task[:user_id])
      unless connection.nil?
        connection.send_sync_building_state(task[:uid], task[:level], true)
      end

      # PlayerFactory.send_message(task[:user_id], response, 'updating')

      MageLogger.instance.info "Task ##{task[:id]} is ready."
    end

    unless tasks_to_delete.empty?
      DBConnection.query(
        "DELETE FROM deferred_tasks WHERE id IN ( #{tasks_to_delete.join(',')} )"
      )
    end
  end

end