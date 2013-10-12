require 'pry'
require 'mysql2'
class DBResources
  def initialize(host = "localhost", username = "root", database = "game_cms")
    @mysql_connection = Mysql2::Client.new(:host => host, :username => username, :database => database)

    print "Loading units ..."
    @units = {}
    results = @mysql_connection.query("SELECT * FROM units").each(:symbolize_keys => true) do |unit|
      @units[unit[:package].to_sym] = unit
    end
    print " #{@units.count} unit(s) \n"
  end

  def get_unit(package)
    @units[package.to_sym].dup
  end

end