

class GameServerStatistics
  # include EM::Deferrable
  @@stats = {}

  def _collect(type, value)
    @@stats[type] = value
  end

  def initialize(val)
    @val = val
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

  def _do

    cb = proc {
      puts('END!')
      # sleep(0.5)
    }

    t = proc {

      loop {
        200000.times do
          rand(20)

          dd = rand(20) * rand(43) * rand(30) * 0.32
          Math.sin(dd)
          Math.sqrt(dd)

        end

        print (@val)
        sleep(0.5)
      }

      # 9999999918.times do |i|
        # print(i)
        
      # end
    }

    EM.defer t, cb
  end

end