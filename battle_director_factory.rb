require 'singleton'

require_relative 'mage_logger.rb'
require_relative 'battle_director.rb'

class BattleDirectorFactory
  include Singleton

  def initialize()
    @battles = {}
  end

  def create()
    # uid = SecureRandom.hex(5)
    battle_director = BattleDirector.new()
    @battles[battle_director.uid()] = battle_director

    battle_director
  end

  def get(uid)
    @battles[uid]
  end

  # def set_opponent(battle_uid, connection, player)
  #   @battles[battle_uid].set_opponent(connection, player)
  # end

  # def enable_ai(battle_uid, ai_uid)
  #   @battles[battle_uid].enable_ai(ai_uid)
  # end

  # def set_opponent_ready(battle_uid, opponent_id)
  #   @battles[battle_uid].set_opponent_ready(opponent_id)
  # end

  # def spawn_unit(battle_uid, unit_uid, player_id)
  #   @battles[battle_uid].spawn_unit(unit_uid, player_id)
  # end

  def update(current_time)
    @battles.each do |battle_uid, battle|
      battle.update_opponents(current_time) if battle.is_started?
    end
  end

end