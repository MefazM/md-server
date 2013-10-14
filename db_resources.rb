require 'pry'
require 'mysql2'

class DBResources

  def self.connect(host = "localhost", username = "root", database = "game_cms")
    print "Connecting to DB..."
    begin
      @@mysql_connection = Mysql2::Client.new(:host => host, :username => username, :database => database)  
    rescue Exception => e
      raise e
    end

    print " OK \n"
  end

  def self.load_resources
    print "Loading units ..."
    @@units = {}
    begin
      results = @@mysql_connection.query("SELECT * FROM units").each(:symbolize_keys => true) do |unit|
        # Cast from integer to bool, 1 == true, other = false
        unit[:range_attack] = unit[:range_attack] == 1
        unit[:melee_attack] = unit[:melee_attack] == 1
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