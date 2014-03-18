

class GameServerStatistics
  include EM::Deferrable
  @@stats = {}

  def _collect(type, value)
    @@stats[type] = value
  end

  def initialize()

  end

  def do
    counter = 0
    100.times do |i|
      # puts "CC: #{i}"

      counter = Math.sin(i) / 0.3 + counter
    end

    sleep(3.5)

    self.succeed(counter)
  end

end