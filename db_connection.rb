require 'mysql2'
require_relative 'mage_logger.rb'

class DBConnection

  def self.connect(host = "localhost", username = "root", database = "game_cms")
    
    MageLogger.instance.info "Connecting to DB..."

    begin
      @@connection = Mysql2::Client.new(:host => host, :username => username, :database => database)

    rescue Exception => e
      raise e
    end

    MageLogger.instance.info "DB connected!"
  end

  def self.escape (string)
    @@connection.escape(string)
  end

  def self.last_inser_id
    @@connection.last_id
  end

  def self.query(sql_query)
    @@connection.query(sql_query, {:symbolize_keys => true, :cast_booleans => true})
  end
end
