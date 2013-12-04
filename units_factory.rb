require 'singleton'

require_relative 'units_factory.rb'
require_relative 'responders.rb'
require_relative 'mage_logger.rb'
require_relative 'player_factory.rb'

require 'pry'
require_relative 'db_connection.rb'

class UnitsFactory
  include Singleton

  def initialize()

    MageLogger.instance.info "UnitsFactory| Loading units from DB ..."
    @units_prototypes = {}
    begin
      DBConnection.query("SELECT * FROM units").each do |unit|
        # Convert ms to seconds
        unit[:melee_attack_speed] *= 0.001 if unit[:melee_attack_speed]
        unit[:range_attack_speed] *= 0.001 if unit[:range_attack_speed]

        unit[:production_time] = 5

        @units_prototypes[unit[:package].to_sym] = unit
      end
    rescue Exception => e
      raise e
    end

    @units_tasks = {}

    MageLogger.instance.info "UnitsFactory| #{@units_prototypes.count} unit(s) - loaded."
  end

  def units_in_queue(player_id)
    current_time = Time.now.to_f
    # @units_tasks[player_id]

    queue = {}
    unless @units_tasks[player_id].nil?
      @units_tasks[player_id].each do |producer_id, producer|
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

          queue[producer_id] << task_info
        end
      end
    end

    # binding.pry

    queue
  end

  def add_production_task(player_id, unit_uid)
    producer_id = @units_prototypes[unit_uid.to_sym][:depends_on_building_package]
    production_time = @units_prototypes[unit_uid.to_sym][:production_time]

    @units_tasks[player_id] = {} if @units_tasks[player_id].nil?

    if @units_tasks[player_id][producer_id].nil?
      @units_tasks[player_id][producer_id] = {:current_task => nil, :tasks => {}}
    end

    task = @units_tasks[player_id][producer_id][:tasks][unit_uid.to_sym]

    if task.nil?
      task = { :count => 1, :production_time => production_time }
    else
      task[:count] += 1
    end

    @units_tasks[player_id][producer_id][:tasks][unit_uid.to_sym] = task
    responce = Respond.as_unit_produce_add(unit_uid, producer_id, production_time)

    PlayerFactory.send_message(player_id, responce, 'push_unit_queue')
  end

  def update_production_tasks()

    current_time = Time.now.to_f

    @units_tasks.each do |player_id, producers|
      producers.each do |producer_id, producers_tasks|

        unless producers_tasks[:current_task].nil?
          if producers_tasks[:current_task][:finish_at] < current_time
            producers_tasks[:current_task] = nil
            unit_uid, task = producers_tasks[:tasks].first
            task[:count] -= 1

            if task[:count] == 0
              producers_tasks[:tasks].delete(unit_uid)

            end

            player = PlayerFactory.get_player_by_id(player_id)
            player.add_unit(unit_uid)

            MageLogger.instance.info "UnitsFactory| Production task finished for player##{player_id}, producer='#{producer_id}', unit added='#{unit_uid}'."
          end
        else
          unit_uid, task = producers_tasks[:tasks].first

          unless task.nil?
            task[:started_at] = current_time
            task[:finish_at] = current_time + task[:production_time]

            producers_tasks[:current_task] = task

            PlayerFactory.send_message(player_id, {:producer_id => producer_id, :production_time => task[:production_time] * 1000}, 'start_unit_queue_task')
          end
        end
      end
    end
  end

  def units(package)
    @units_prototypes[package.to_sym]
  end

end