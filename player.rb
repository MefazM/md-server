

class Player
  include Celluloid
  include Celluloid::IO

  def initialize (socket)
    @socket = socket
    @status = :run

    @uid = rand 1100

    puts "I: #{@uid}"
  end

  def run

    async._dispatch
    async._listen

  end

  def _listen
    loop {
      data = @socket.readpartial(4096)
      puts("***#{data.inspect}")
    }


    rescue EOFError
      # puts "*** #{host}:#{port} disconnected"
      @socket.close
      @status = :term
    # end
  end

  def _dispatch

    loop {

      return if @status == :term
      dd = rand(5) * 0.5
      @socket.write "Sleep for: #{dd}\n\r"

      results = Storage::Mysql::Pool.connections_pool.with do |conn|
        conn.query("SELECT * FROM units WHERE id=3").first
      end

      redis_results = Storage::Redis::Pool.connections_pool.with do |redis|
        redis.connection.hget("players:44:resources", "coins")
      end

      puts("#{@uid} MS: #{results[:name]}")
      puts("#{@uid} REDIS: #{redis_results.inspect}")
    }

  end
end