module Storage
  class GameData
    # Define getters

    def self.collected_data
      @@collected_data
    end

    def self.coin_generator_uid
      @@coin_generator_uid
    end

    def self.storage_building_uid
      @@storage_building_uid
    end

    def self.spells_data
      @@spells_data
    end

    def self.unit_price uid
      @@collected_data[:units_data][uid][:price]
    end

    def self.units
      @@collected_data[:units_data]
    end

    def self.unit uid
      @@collected_data[:units_data][uid]
    end

    def self.building uid
      @@collected_data[:buildings_data][uid]
    end

    def self.load!
      Celluloid::Logger::info 'Loading game data...'

      @@mysql = Mysql::MysqlClient.new

      # Process game settings
      game_settings = {}
      @@mysql.select("SELECT * FROM game_settings").each do |option|
        game_settings[option[:key].to_sym] = option[:value]
      end
      # Convert JSON data.
      [:storage_capacity_per_level, :coins_generation_per_level].each do |type|
        game_settings[type] = JSON.parse(game_settings[type])
      end
      # Coins
      @@coins_generation_per_level = []
      game_settings[:coins_generation_per_level].each do |data|
        @@coins_generation_per_level << {
          :amount => data['amount'].to_f,
          :harvester_capacity => data['harvest_capacity'].to_i
        }
      end

      @@storage_capacity_per_level = []
      game_settings[:storage_capacity_per_level].each do |data|
        @@storage_capacity_per_level << data['amount'].to_i
      end

      @@coin_generator_uid = game_settings[:coin_generator_uid].to_sym
      @@storage_building_uid = game_settings[:storage_building_uid].to_sym

      # Collect and process game objects
      units = @@mysql.select("SELECT * FROM units")

      @@collected_data = {
        :buildings_production => self.export_buildings_production(units) ,
        :units_data => self.export_units(units),
        :buildings_data => self.load_buildings
      }

      @@spells_data = self.load_spells

      # Kill mysql connection!
      @@mysql.finalize
      @@mysql = nil
    end

    def self.harvester level
      @@coins_generation_per_level[level]
    end

    def self.storage_capacity level
      @@storage_capacity_per_level[level]
    end

    private

    def self.export_buildings_production units
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

    def self.export_units units
      units_data = {}
      units.each do |unit|
        data = {}
        [ :name, :description, :health_points,
          :movement_speed, :production_time,
          :depends_on_building_level, :price ].each do |attr|

          data[attr] = unit[attr]
        end

        data[:depends_on_building_uid] = unit[:depends_on_building_uid].to_sym

        [:range_attack, :melee_attack].each do |attack_type|
          if unit[attack_type] == true
            attack_data = {}
            [:power_max, :power_min, :range].each do |attack_field|
              value = unit["#{attack_type}_#{attack_field}".to_sym]
              attack_data[attack_field] = value
            end
            # Convert attack speed in ms to server seconds
            attack_speed_key = "#{attack_type}_speed".to_sym
            attack_data[:speed] = unit[attack_speed_key] * 0.001

            damage_type = unit["#{attack_type}_damage_type".to_sym]
            attack_data[:type] = damage_type unless damage_type.nil?

            data[attack_type] = attack_data
          end
        end

        units_data[unit[:uid].to_sym] = data
      end

      units_data
    end

    def self.load_buildings
      buildings_data = {}
      @@mysql.select("SELECT * FROM buildings").each do |building|
        building_uid = building[:uid].to_sym
        uid = "#{building_uid}_#{building[:level]}"
        # buildings_data[uid] = [] if buildings_data[uid].nil?

        buildings_data[uid] = {}

        [:name, :description, :production_time, :price].each do |attr|
          buildings_data[uid][attr] = building[attr]
        end

        buildings_data[uid][:actions] = {
          :build => self.updateable?(building[:uid], building[:level]),
          :info => @@coin_generator_uid != building_uid,
          :units => self.produce_units?(building[:uid], building[:level]),
          :harvest_collect => @@coin_generator_uid == building_uid,
          :harvest_info => @@coin_generator_uid == building_uid
        }
      end

      buildings_data
    end

    def self.updateable? uid, level
      target_level = level + 1
      building = @@mysql.select("SELECT * FROM buildings WHERE level = #{target_level} AND uid = '#{uid}'").first

      building.nil? == false
    end

    def self.produce_units? uid, level
      units = @@mysql.select("SELECT * FROM units WHERE depends_on_building_uid = '#{uid}' AND depends_on_building_level = #{level}")
      units.count > 0
    end

    def self.load_spells
      spells_data = {}

      @@mysql.select("SELECT * FROM spells").each do |spell_data|
        # Convert ms to seconds
        uid = spell_data[:uid].to_sym
        time = spell_data[:time] || 0
        spell_prototype = {
          :uid => uid,
          :time_s => time * 0.001,
          :time_ms => time,
          :area => spell_data[:area],
          :vertical_area => spell_data[:vertical_area],
          :manacost => spell_data[:manacost],
          :description => spell_data[:description]
        }
        # Get spel attrs
        @@mysql.select("SELECT * FROM spells_attrs WHERE spell_id = #{spell_data[:id]}").each do |spell_attrs|
          key = spell_attrs[:key]
          value = spell_attrs[:value]

          spell_prototype[key.to_sym] = value
        end

        spells_data[uid] = spell_prototype

      end

      spells_data
    end

  end
end
