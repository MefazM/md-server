require 'singleton'

require_relative 'mage_logger.rb'
require_relative 'battle_director.rb'

class BattleDirectorFactory
  include Singleton

  def initialize()
    @battles = {}
  end

  def create()
    battle_director = BattleDirector.new()
    @battles[battle_director.uid()] = battle_director

    battle_director
  end

  def get(uid)
    @battles[uid]
  end

  def update(current_time)
    @battles.each do |battle_uid, battle|
      battle.update_opponents(current_time) if battle.is_started?
    end
  end

end