require 'singleton'

require_relative 'mage_logger.rb'
require_relative 'player_factory.rb'

class BuildingsFactory
  include Singleton

  def initialize()
    @buildings_prototypes = {}
    sql = "SELECT * FROM buildings"
    building = DBConnection.query(sql).each do |building|
      uid = building[:package]
      level = building[:level]

      @buildings_prototypes[uid] = {} if @buildings_prototypes[uid].nil?
      @buildings_prototypes[uid][level] = building
    end
  end

  def build_or_update(player_id, package)
    player = PlayerFactory.get_player_by_id(player_id)
    update_level = player.get_building_level(package) + 1

    building_to_construct = @buildings_prototypes[package][update_level]
    if building_to_construct.nil?
      MageLogger.instance.info "BuildingsFactory| Building not found! package = #{package}, level = #{update_level}"
      return false
    end
    task_id = DeferredTasks.instance.add_task_with_no_sequence(player_id, building_to_construct)
    time = building_to_construct[:production_time]
    #convert to ms
    time *= 1000
    connection = PlayerFactory.connection(player_id)
    unless connection.nil?
      connection.send_sync_building_state(package, update_level, false, time)
    end
  end

end
