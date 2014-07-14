require 'yaml'

module Storage
  module GameData
    class << self

      attr_reader :player_levels, :coin_generator_uid,
        :storage_building_uid, :battle_score_settings,
        :game_rate, :ai_presets, :loser_modifier, :score_to_coins_modifier

      def load!
        Celluloid::Logger::info 'Loading game data...'

        mysql_connection = Mysql::MysqlClient.new

        @settings = JSON.parse( IO.read(GAME_SETTINGS_JSON_PATH) )

        @settings.recursive_symbolize_keys!

        @game_rate = @settings[:game_rate]
        @loser_modifier = @settings[:loser_modifier]
        @score_to_coins_modifier = @settings[:score_to_coins_modifier].to_f

        @coin_generator_uid = @settings[:coins_production][:coin_generator_uid].to_sym
        @storage_building_uid = @settings[:coins_production][:storage_building_uid].to_sym

        @battle_score_settings = @settings[:battle_achievements]

        @max_player_level = @settings[:player_settings_per_level].length
        @player_levels = @settings[:player_settings_per_level]

        load_units mysql_connection
        load_spells mysql_connection
        load_buildings mysql_connection

        mysql_connection.finalize
        mysql_connection = nil

        @ai_presets = {
          :ai_easy => {
            :units => {:sub => 1, :mage => 1, :elf => 1, :horse => 1, :crusader => 1},
            :activity_period => 4.0,

            :level => 2,
            :name => "Wilford Dragan (easy)",

            :heal => [:arrow_earth],
            :buff => [:arrow_fire],
            :debuff => [:rect_water],
            :atk_spell => [:circle_water]
          },
          :ai_normal => {
            :units => {:sub => 15, :elf => 10, :crusader => 50},
            :activity_period => 3.0,
            :level => 2,
            :name => "Galkir Cantilever (normal)",

            :heal => [:arrow_earth],
            :buff => [:arrow_fire],
            :debuff => [:rect_air, :rect_water],
            :atk_spell => [:z_air]
          },
          :ai_hard => {
            :units => {:sub => 35, :mage => 15, :elf => 25, :horse => 6, :crusader => 50},
            :activity_period => 1.5,

            :level => 6,
            :name => "Krag Zarkanan (hard)",

            :heal => [:circle_earth, :arrow_earth],
            :buff => [:arrow_fire, :arrow_air],
            :debuff => [:z_water, :rect_air, :arrow_water, :rect_water, :z_fire],
            :atk_spell => [:z_air, :circle_water, :circle_fire]
          }
        }
      end

      def next_level_at level
        level = [level, @max_player_level - 1].min

        @player_levels[level][:level_at]
      end

      def battle_reward level
        level = [level, @max_player_level - 1].min

        @player_levels[level][:static_reward]
      end

      def initialization_data
        {
          :buildings_production => @buildings_produce_units,
          :units_data => @units_data,
          :buildings_data => @buildings_data
        }
      end

      def spell_data uid
        @spells_data[uid.to_sym]
      end

      def unit uid
        @units_data[uid.to_sym]
      end

      def building uid
        @buildings_data[uid.to_sym]
      end

      def mana_storage level
        max_mana_level = @settings[:mana_storage_settings].length
        level = [level, max_mana_level - 1].min

        @settings[:mana_storage_settings][level]
      end

      def coins_harvester level
        coins_generation_per_level = @settings[:coins_production][:coins_generation_per_level]

        max_harvester_level = coins_generation_per_level.length
        level = [level, max_harvester_level - 1].min

        coins_generation_per_level[level]
      end

      def coins_storage_capacity level
        storage_capacity_per_level = @settings[:coins_production][:storage_capacity_per_level]

        max_storage_capacity_level = storage_capacity_per_level.length
        level = [level, max_storage_capacity_level - 1].min

        storage_capacity_per_level[level]
      end

      private

      def load_units mysql_connection

        units = mysql_connection.select("SELECT * FROM units")

        @units_data = {}
        @buildings_produce_units = {}

        @battle_score_settings ||= {}

        units.each do |unit|
          data = {}
          [:name, :description, :health_points,
           :movement_speed, :production_time,
           :price, :score_price, :depends_on_building_level].each do |attr|

            data[attr] = unit[attr]
          end

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

          unit_uid = unit[:uid].to_sym
          # Relation to building
          unless unit[:depends_on_building_uid].empty?

            building_uid = unit[:depends_on_building_uid].to_sym

            data[:depends_on_building_uid] = building_uid

            @buildings_produce_units[building_uid] ||= []

            @buildings_produce_units[building_uid] << {
              :uid => unit_uid,
              :level => unit[:depends_on_building_level]
            }
          end

          @units_data[unit_uid] = data
          #Score paid for killing this unit
          @battle_score_settings[unit_uid] = {
            :score_price => data[:score_price] || 0
          }

        end
      end

      def load_buildings mysql_connection
        @buildings_data = {}

        is_updateable = Proc.new {|uid, level|
          target_level = level + 1
          building = mysql_connection.select("SELECT * FROM buildings WHERE level = #{target_level} AND uid = '#{uid}'").first

          not building.nil?
        }

        is_unit_producer = Proc.new{|uid, level|
          units = mysql_connection.select("SELECT * FROM units WHERE depends_on_building_uid = '#{uid}' AND depends_on_building_level = #{level}")
          units.count > 0
        }

        mysql_connection.select("SELECT * FROM buildings").each do |building|
          building_uid = building[:uid].to_sym
          key = :"#{building_uid}_#{building[:level]}"

          @buildings_data[key] = {}

          [:name, :description, :production_time, :price].each do |attr|
            @buildings_data[key][attr] = building[attr]
          end

          @buildings_data[key][:actions] = {
            :build => is_updateable.call(building[:uid], building[:level]),
            :info => @coin_generator_uid != building_uid,
            :units => is_unit_producer.call(building[:uid], building[:level]),
            :harvest_collect => @coin_generator_uid == building_uid,
            :harvest_info => @coin_generator_uid == building_uid
          }
        end
      end

      def load_spells mysql_connection
        @spells_data = {}

        # @battle_score_settings ||= {}

        mysql_connection.select("SELECT * FROM spells").each do |spell_data|
          # Convert ms to seconds
          uid = spell_data[:uid].to_sym
          time = spell_data[:time] || 0
          spell_prototype = {
            :uid => uid,
            :time_s => time * 0.001,
            :time_ms => time,
            :area => spell_data[:area],
            :vertical_area => spell_data[:vertical_area],
            :mana_cost => spell_data[:mana_cost],
            :description => spell_data[:description]
          }
          # Get spel attrs
          mysql_connection.select("SELECT * FROM spells_attrs WHERE spell_id = #{spell_data[:id]}").each do |spell_attrs|
            key = spell_attrs[:key]
            value = spell_attrs[:value]

            spell_prototype[key.to_sym] = value
          end

          @spells_data[uid] = spell_prototype
        end
      end

    end
  end
end