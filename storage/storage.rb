

require 'connection_pool'
require 'storage/mysql_client'
require 'storage/redis_client'
require 'storage/game_data'

module Storage

  module Mysql
    class Pool
      @@connections_pool = nil

      def self.connections_pool
        raise "Mysql connections pool is not initialized" if @@connections_pool.nil?

        @@connections_pool
      end

      def self.create!
        @@connections_pool = ConnectionPool.new(size: MYSQL_CONNECTIONS_POOL) { MysqlClient.new }

        Celluloid::Logger::info "Mysql connections pool created."
      end

    end
  end

  module Redis
    class Pool
      @@connections_pool = nil

      def self.connections_pool
        raise "Redis connections pool is not initialized" if @@connections_pool.nil?

        @@connections_pool
      end

      def self.create!
        @@connections_pool = ConnectionPool.new(size: REDIS_CONNECTIONS_POOL) { RedisClient.new }

        Celluloid::Logger::info "Redis connections pool created."
      end
    end
  end
end