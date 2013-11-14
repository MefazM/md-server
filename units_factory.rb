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
        unit[:melee_attack_speed] = unit[:melee_attack_speed] * 0.001 if unit[:melee_attack_speed]
        unit[:range_attack_speed] = unit[:range_attack_speed] * 0.001 if unit[:range_attack_speed]

        @units_prototypes[unit[:package].to_sym] = unit
      end
    rescue Exception => e
      raise e
    end

    @units_tasks = {}

    MageLogger.instance.info "UnitsFactory| #{@units_prototypes.count} unit(s) - loaded."
  end

  def add_production_task(player_id, unit_uid)
    producer_id = @units_prototypes[unit_uid.to_sym][:depends_on_building_package]

    production_time = 10

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

            MageLogger.instance.info "UnitsFactory| Production task finished for player##{player_id}, producer='#{producer_id}', unit added='#{unit_uid}'."
          end
        else
          unit_uid, task = producers_tasks[:tasks].first

          unless task.nil?
            task[:started_at] = current_time
            task[:finish_at] = current_time + task[:production_time]

            producers_tasks[:current_task] = task

          end
        end
      end
    end
  end

  def units(package)
    @units_prototypes[package.to_sym]
  end

end