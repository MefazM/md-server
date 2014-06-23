module Battle
  class AiPlayer

    attr_accessor :units, :username

    def initialize
      @units = {:mage => 4, :elf => 4}
      @id = rand(0...99999)
      @username = "Untitled Ki Borg"

      @level = 5
    end

    def battle_data
      {
        :id => @id,
        :units => @units,
        :mana => {},
        :level => @level,
        :username => @username,
        :is_ai => true
      }
    end

    def default_unit_uid()
      'crusader'
    end

  end
end