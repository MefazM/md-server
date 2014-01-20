require 'singleton'
require 'json'

class GameData
  include Singleton

  def initialize
    MageLogger.instance.info "GameData| Loading resources from DB ..."

    units = DBConnection.query("SELECT * FROM units")
    buildings = DBConnection.query("SELECT * FROM buildings")
    # Process game settings
    coins_production_data = {}
    coins_production = DBConnection.query("SELECT * FROM game_settings")
    coins_production.each do |option|
      coins_production_data[option[:key].to_sym] = option[:value]
    end
    # Convert JSON data.
    [:storage_capacity_per_level, :coins_generation_per_level].each do |type|
      coins_production_data[type] = JSON.parse(coins_production_data[type])
    end
    @coins_generation_per_level = []
    coins_production_data[:coins_generation_per_level].each do |data|
      @coins_generation_per_level << {
        :amount => data['amount'].to_f,
        :harvester_capacity => data['harvest_capacity'].to_i
      }
    end

    @storage_capacity_per_level = []
    coins_production_data[:storage_capacity_per_level].each do |data|
      @storage_capacity_per_level << data['amount'].to_i
    end

    @coin_generator_uid = coins_production_data[:coin_generator_uid].to_sym
    @storage_building_uid = coins_production_data[:storage_building_uid].to_sym
    # Collect and process game objects
    @collected_data = {
      :buildings_production => export_buildings_production(units) ,
      :units_data => export_units(units),
      :buildings_data => export_buildings(buildings)
    }
  end

  def collected_data
    @collected_data
  end

  def harvester level
    @coins_generation_per_level[level]
  end

  def storage_capacity level
    @storage_capacity_per_level[level]
  end

  def coin_generator_uid
    @coin_generator_uid
  end

  def storage_building_uid
    @storage_building_uid
  end

  private

  def export_buildings_production units
    units_by_building = {}
    units.each do |unit|
      building_uid = unit[:depends_on_building_uid].to_sym
      unless building_uid.empty?
        units_by_building[building_uid] = [] if units_by_building[building_uid].nil?
        units_by_building[building_uid] << {
          :uid => unit[:uid],
          :level => unit[:depends_on_building_level]
        }
      end
    end

    units_by_building
  end


  def export_units units
    units_data = {}
    units.each do |unit|
      data = {}
      [:name, :description, :health_points, :movement_speed, :production_time].each do |attr|
        data[attr] = unit[attr]
      end

      [:range_attack, :melee_attack].each do |attack_type|
        if unit[attack_type] == true
          attack_data = {}
          [:power_max, :power_min, :range, :speed].each do |attack_field|
            value = unit["#{attack_type}_#{attack_field}".to_sym]
            attack_data[attack_field] = value
          end
          damage_type = unit["#{attack_type}_damage_type".to_sym]
          attack_data[:type] if damage_type == true

          data[attack_type] = attack_data
        end
      end

      units_data[unit[:uid]] = data
    end

    units_data
  end

  def export_buildings buildings
    buildings_data = {}
    buildings.each do |building|
      building_uid = building[:uid].to_sym
      uid = "#{building_uid}_#{building[:level]}"
      # buildings_data[uid] = [] if buildings_data[uid].nil?

      buildings_data[uid] = {}

      [:name, :description, :production_time].each do |attr|
        buildings_data[uid][attr] = building[attr]
      end

      buildings_data[uid][:actions] = {
        :build => updateable?(building[:uid], building[:level]),
        :info => @coin_generator_uid != building_uid,
        :units => produce_units?(building[:uid], building[:level]),
        :harvest_collect => @coin_generator_uid == building_uid,
        :harvest_info => @coin_generator_uid == building_uid
      }
    end

    buildings_data
  end

  def updateable? uid, level
    target_level = level + 1
    building = DBConnection.query("SELECT * FROM buildings WHERE level = #{target_level} AND uid = '#{uid}'").first
    return building.nil? == false
  end

  def produce_units? uid, level
    units = DBConnection.query("SELECT * FROM units WHERE depends_on_building_uid = '#{uid}' AND depends_on_building_level = #{level}")
    return units.count > 0
  end
end