require_relative 'player'

class AiPlayer < Player

  def initialize

  end

  def get_default_unit_package()
    'crusader'
  end

  def get_units_data_for_battle()
    ['stone_golem', 'mage', 'doghead', 'elf']
  end

end
