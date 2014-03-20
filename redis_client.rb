require 'celluloid/redis'

module Storage
  module Redis
    class RedisClient
      attr_reader :connection

      def initialize
        begin

          @connection = ::Redis.new(:driver => :celluloid)

        rescue Exception => e
          error e
          raise e
        end

        ObjectSpace.define_finalizer(self, method(:finalize))
      end

      def finalize
        @connection.quit
      end
    end
  end
end