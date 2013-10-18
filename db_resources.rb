require 'pry'
require_relative 'db_connection.rb'

class DBResources

  def self.load_resources
    print "Loading units ..."
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

    print " OK [#{@@units.count} unit(s)] \n"
  end

  def self.get_unit(package)
    @@units[package.to_sym].dup
  end


end