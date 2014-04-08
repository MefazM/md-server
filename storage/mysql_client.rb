require "jdbc/mysql"
Jdbc::MySQL.load_driver

require "java"

module Storage
  module Mysql
    class MysqlClient
      include Celluloid::Logger

      def initialize
        Java::com.mysql.jdbc.Driver

        info "Mysql client connection to #{MYSQL_HOST}..."

        user_url = "jdbc:mysql://#{MYSQL_HOST}/#{MYSQL_DB_NAME}"
        begin
          @connections = java.sql.DriverManager.get_connection(user_url, MYSQL_USER_NAME, MYSQL_PASSWORD)
          @statement = @connections.create_statement
        rescue Exception => e
          error e
          raise e
        end

        ObjectSpace.define_finalizer(self, method(:finalize))
      end

      def finalize
        @statement.close
        @connections.close

        info "Mysql client connection closed."
      end

      def escape (string)
        string
      end

      def last_inser_id
        @statement.lastInsertID
      end

      def query(sql_query)

        result_set = @statement.execute_query(sql_query)

        meta = result_set.getMetaData()
        col_names = []
        for i in 1..meta.getColumnCount()
          col_names << meta.getColumnName(i)
        end

        data = []

        while (result_set.next) do
          res = {}
          col_names.each do |name|
            res[name.to_sym] = result_set.getObject(name)
          end

          data << res
        end

        data
      end
    end
  end
end