require 'uri'
# require 'httparty'

class GameStatistics
  include Celluloid
  include Celluloid::Notifications
  include Celluloid::Logger

  # include HTTParty

  STATISTICS_CHANNEL = :statistics_channel

  SUBMIN_DATA_PERIOD = 3

  def initialize
    info "Statistics reporter..."

    subscribe(STATISTICS_CHANNEL, :receive_message)

    @data = {}

    run

    Actor[:statistics] = Actor.current

    @data[:cur_battles] = 0
    @data[:cur_players] = 0
  end

  # private

  def run
    @submin_data_timer = after(SUBMIN_DATA_PERIOD) {

      # submit_statistics

      @submin_data_timer.reset
    }
  end

  def receive_message(topic, payload)

    trigger = payload[0]

    binding.pry

    send trigger

  rescue Exception => e

    error "Can't execute statistics trigger \n #{e}"
  end

  def battle_started

    @data[:cur_battles] += 1
  end

  def battle_ended
    @data[:cur_battles] -= 1
  end

  def player_connected

    @data[:cur_players] += 1
  end

  def player_disconnected

    @data[:cur_players] -= 1
  end

  # def add_data group, value, i
  #   group_name = group.to_sym

  #   @data[group_name] ||= []
  #   @data[group_name] << {:time => Time.now.to_i + i * 3000, :value => value}
  # end

  def submit_statistics

    puts " S: \
      Active players: #{@data[:cur_players]} \
      Active battles: #{@data[:cur_battles]} \
    "

    # info "Submit"

    # data = @data.dup
    # @data = []

    # HTTParty.post( API_BASE_PATH, :body => { :statistics => data })

    rescue Exception => e
      error "Error while sending statistics to server \n #{e}"
  end

end
