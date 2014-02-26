require_relative 'abstract_spell.rb'
require_relative 'haste.rb'
require_relative 'slow.rb'
require_relative 'fireball.rb'
require_relative 'heal.rb'
require_relative 'poison.rb'
require_relative 'regeneration.rb'
require_relative 'wind_blow.rb'
require_relative 'stun.rb'
require_relative 'bomb.rb'
require_relative 'thunder.rb'
require_relative 'curse.rb'
require_relative 'bless.rb'

class SpellFactory
  @@spells = {}

  @@spells[:circle_fire] = Fireball
  @@spells[:circle_earth] = Heal
  @@spells[:circle_water] = Bomb

  @@spells[:arrow_air] = Haste
  @@spells[:arrow_water] = Slow
  @@spells[:arrow_earth] = Regeneration
  @@spells[:arrow_fire] = Bless

  @@spells[:z_water] = Poison
  @@spells[:z_air] = Thunder
  @@spells[:z_fire] = Curse

  @@spells[:rect_air] = WindBlow
  @@spells[:rect_water] = Stun

  def self.create(data, brodcast_callback)
    klass = @@spells[data[:uid]]

    if klass
      return klass.new(data, brodcast_callback)
    else
      MageLogger.instance.error "SpellFactory| Ability preset (#{klass}) not found."
    end

    return nil
  end
end