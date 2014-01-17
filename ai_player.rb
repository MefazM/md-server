require_relative 'player'

class AiPlayer < Player

  def initialize

  end

  def default_unit_uid()
    'crusader'
  end

  def units_data_for_battle()
    ['stone_golem', 'mage', 'doghead', 'elf']
  end

end
