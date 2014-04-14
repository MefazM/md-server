require "jdbc/mysql"
Jdbc::MySQL.load_driver

require "java"

module Storage
  module Mysql
    # TODO: refactor to sql builder
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

      def escape string
        string
      end

      def last_inser_id
        @statement.lastInsertID
      end

      def insert(table, data)

        return if !data.kind_of?(Hash) || data.empty?

        statements = []

        data.each do |name, value|
          escaped_value = value.kind_of?(Numeric) ? value : "'#{value}'"
          statements << "#{name} = #{escaped_value}"
        end

        sql = "INSERT INTO #{table} SET #{statements.join(',')}"

        begin
          @statement.execute_update sql
        rescue Exception => e
          error "Can't execute sql! \n #{sql} \n #{e}"
        end
      end

      def select sql

        result_set = @statement.execute_query sql

        meta = result_set.getMetaData
        col_names = []
        for i in 1..meta.getColumnCount
          col_names << meta.getColumnName(i)
        end

        data = []

        while result_set.next do
          res = {}
          col_names.each do |name|
            res[name.to_sym] = result_set.getObject name
          end

          data << res
        end

        data
      end
    end
  end
end