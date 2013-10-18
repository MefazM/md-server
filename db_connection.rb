require 'mysql2'

class DBConnection

  def self.connect(host = "localhost", username = "root", database = "game_cms")
    print "Connecting to DB..."
    begin
      @@connection = Mysql2::Client.new(:host => host, :username => username, :database => database)


    rescue Exception => e
      raise e
    end

    print " OK \n"
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