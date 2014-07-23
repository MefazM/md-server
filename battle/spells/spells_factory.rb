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
require_relative 'poison_cloud.rb'

class SpellFactory
  # Ugly mapping
  @@spells = {
    :circle_fire => Fireball,
    :circle_earth => Heal,
    :circle_water => Bomb,

    :arrow_air => Haste,
    :arrow_water => Slow,
    :arrow_earth => Regeneration,
    :arrow_fire => Bless,

    :z_water => Poison,
    :z_air => Thunder,
    :z_fire => Curse,
    :z_earth => PoisonCloud,

    :rect_air => WindBlow,
    :rect_water => Stun,
  }

  def self.create(data, player_id)
    klass = @@spells[data[:uid]]

    if klass.nil?
      Celluloid::Logger::error "Spell klass preset (#{klass}) not found!"
      return nil
    end

    klass.new(data, player_id)
  end
end
