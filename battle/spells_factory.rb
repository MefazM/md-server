require_relative 'spells_presets/abstract_spell.rb'
require_relative 'spells_presets/damage.rb'
require_relative 'spells_presets/heal.rb'
require_relative 'spells_presets/push.rb'
require_relative 'spells_presets/stun.rb'

class SpellFactory
  # {
  #   :id=>2,
  #   :uid=>"zeee_wind",
  #   :time=>1.2,
  #   :value=>6,
  #   :description=>"Just a spark",
  #   :area=>10,
  #   :target_type=>2,
  #   :mana_cost=>20,
  #   :ability_preset=>2,
  #   :processing_type=>0
  # }

  @@spells = {}

  @@spells[:heal] = Heal
  @@spells[:push] = Push
  @@spells[:stun] = Stun
  @@spells[:damage] = Damage

  def self.create(data, target_area, unit_pool)
    klass = @@spells[data[:ability_preset]]

    if klass
      return klass.new(data, target_area, unit_pool)
    else
      MageLogger.instance.error "SpellFactory| Ability preset (#{klass}) not found."
    end

    return nil
  end

end