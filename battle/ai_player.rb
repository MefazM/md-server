module Battle
  class AiPlayer

    attr_accessor :units

    def initialize
      @units = {:mage => 4, :elf => 4}
    end

    def default_unit_uid()
      'crusader'
    end

  end
end