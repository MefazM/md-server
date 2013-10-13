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