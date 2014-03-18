# require 'mysql2'
require 'pry'
require "jdbc/mysql"
Jdbc::MySQL.load_driver
require "java"

require_relative 'mage_logger.rb'

class DBConnection

  def self.connect(host, username, database, password)

    Java::com.mysql.jdbc.Driver

    userurl = "jdbc:mysql://#{host}/#{database}"
    @@connSelect = java.sql.DriverManager.get_connection(userurl, username, password)
    @@stmtSelect = @@connSelect.create_statement

    MageLogger.instance.info "Connecting to DB..."

    begin
      # @@connection = Mysql2::Client.new(:host => host, :username => username,
        # :database => database, :password => password)

      

    rescue Exception => e
      raise e
    end

    MageLogger.instance.info "DB connected!"
  end

  def self.escape (string)
    string
    # @@connection.escape(string)
  end

  def self.last_inser_id
    @@connection.last_id
  end

  def self.query(sql_query)

    dd = @@stmtSelect.execute_query(sql_query)

    rsmd = dd.getMetaData()
    names = []
    for i in 1..rsmd.getColumnCount()
      names << rsmd.getColumnName(i)
    end
    results = []

    while (dd.next) do
      res = {}
      names.each do |name|
        res[name.to_sym] = dd.getObject(name)
      end

      results << res
    end

    results
    # binding.pry
    # rsS = stmtSelect.execute_query(selectquery)
    # @@connection.query(sql_query, {:symbolize_keys => true, :cast_booleans => true})
  end
end
