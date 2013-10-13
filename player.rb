require "securerandom"
require 'pry'

class Player

  module States
    LOGIN = 1
    IN_WORLD = 2
    IN_BATTLE = 3
    READY_TO_FIGHT = 4
  end

  def initialize(token)
    @id = token
    @state = States::LOGIN
    @latency = 0
  end

  def get_game_data()
    return {:buildings => {}, :technologies => {}, :units => {}}
  end

  def get_id()
    return @id
  end

  def get_default_unit_package()
    'peasant'
  end
end
