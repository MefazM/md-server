require "jdbc/mysql"
Jdbc::MySQL.load_driver

require "java"

Java::com.mysql.jdbc.Driver
java_import 'java.sql.DriverManager'

module Storage
  module Mysql

    class MysqlClient
      include Celluloid::Logger

      def insert(table, data)
        return if !data.kind_of?(Hash) || data.empty?

        params = []

        data.each do |name, value|
          escaped_value = value.kind_of?(Numeric) ? value : "'#{value}'"
          params << "#{name} = #{escaped_value}"
        end

        sql = "INSERT INTO #{table} SET #{params.join(',')}"

        perform do |statement|
          statement.execute_update sql
          statement.lastInsertID
        end
      end

      def select sql
        perform do |statement|
          result_set = statement.execute_query sql
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

      private

      def perform &block
        connections = java.sql.DriverManager.get_connection("jdbc:mysql://#{MYSQL_HOST}/#{MYSQL_DB_NAME}", MYSQL_USER_NAME, MYSQL_PASSWORD)
        statement = connections.create_statement

        results = yield statement

        statement.close
        connections.close

        results
      end

      def escape string
        string
      end

    end
  end
end