require 'pry'
require_relative 'db_connection.rb'

class DBResources

  def self.load_resources
    MageLogger.instance.info "Loading units from DB ..."
    @@units = {}
    begin
      DBConnection.query("SELECT * FROM units").each do |unit|
        # Convert ms to seconds
        unit[:melee_attack_speed] = unit[:melee_attack_speed] * 0.001 if unit[:melee_attack_speed]
        unit[:range_attack_speed] = unit[:range_attack_speed] * 0.001 if unit[:range_attack_speed]

        @@units[unit[:package].to_sym] = unit
      end
    rescue Exception => e
      raise e
    end

    MageLogger.instance.info "#{@@units.count} unit(s) - loaded."
  end

  def self.get_unit(package)
    @@units[package.to_sym].dup
  end

  # Этот метод должен быть в Player. Достает тех юнитов которые есть у игрока в данный момент.
  def self.get_units(units_ids)
    units = []
    @@units.each do |uid, unit|
      units << {:uid => uid, :count => 3} if units_ids.include? uid.to_s
    end

    units
  end

end