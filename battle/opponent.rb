class Opponen
  attr_accessor :id, :main_building, :units_pool

  def initialize(data, connection = nil)
    @id = data[:id]
    # Units data, available and lost
    @units = {}
    data[:units].each do |uid, count|
      @units[uid] = {
        :available => count,
        :lost => 0
      }
    end

    @ready = false
    @units_pool = []
    @main_building = BattleBuilding.new( 'building_1', 0.1 )

    @spells = []

    @connection = connection

    @ai = false
    if @connection.nil?
      @ai = true
      @ready = true
    end
  end

  def lose?
    @main_building.dead?
  end

  def add_spell(spell_uid)

  end

  def finish_battle!(loser_id)
    # Sync player data, if not AI
    unless @ai
      player = PlayerFactory.instance.player(@id)
      player.unfreeze!
      player.sync_after_battle({
        :units => @units
      })
      # Notificate about battle ended
      @connection.send_finish_battle(loser_id)
    end
  end

  def sort_units!
    @units_pool.sort_by!{|v| v.position}.reverse!
  end

  def send_game_data!(shared_data)
    unless @connection.nil?
      @connection.send_create_new_battle_on_client( @id, @units, shared_data )
    end
  end

  def send_spell_cast!(spell_uid, target_area, opponent_uid, area)
    unless @connection.nil?
      @connection.send_spell_cast(
        spell_uid, target_area, opponent_uid, area
      )
    end
  end

  def send_sync_data!(sync_data)
    unless @connection.nil?
      @connection.send_battle_sync( sync_data )
    end
  end

  def update(opponent, iteration_delta)
    # First need to sort opponent units by distance
    opponent.sort_units!

    sync_data_arr = []
    # To prevent units attack one opponent unit, and share attacks
    # use opponent_unit_id, it will itereate after each unit attack
    # and become zero if attack is not possible
    opponent_unit_id = 0
    # update each unit and collect unit response
    @units_pool.each_with_index do |unit, index|
      # Unit state allow attacks?
      if unit.can_attack?
        opponent_unit_id = make_attack(opponent, unit, opponent_unit_id)
      end
      # collect updates only if unit has change
      if unit.update(iteration_delta)
        sync_data_arr << unit.sync_data
      end

      if unit.dead?
        # Iterate lost unit counter
        unit_data = @units[unit.name]
        unless unit_data.nil?
          unit_data[:lost] += 1
        end
        @units_pool.delete_at(index)
        # unit = nil
      end
    end

    @spells.each_with_index do |spell, index|
      spell.find_targets()
    end

    # Main building - is a main game trigger.
    # If it is destroyed - player loses
    # main_building = player[:main_building]
    @main_building.update(iteration_delta)
    # Send main bulding updates only if has changes
    if @main_building.changed?
      sync_data_arr << [main_building.uid, main_building.health_points]
    end

    return sync_data_arr
  end

  def ready!
    @ready = true
  end

  def ready?
    @ready = true
  end

  def start_battle!
    @connection.send_start_battle() unless @connection.nil?
  end

  def add_unit_to_pool(unit_name, validate)
    valid = !validate

    if validate
      unit_data = @units[unit_name]
      if !unit_data.nil? and unit_data[:available] > 0
        unit_data[:available] -= 1
        valid = true
      end
    end

    if valid
      unit = BattleUnit.new(unit_name)
      @units_pool << unit

      return unit.uid
    end

    return nil
  end

  def notificate_unit_spawn!(unit_uid, unit_name, player_id)
    @connection.send_unit_spawning(
      unit_uid, unit_name, player_id
    ) unless @connection.nil?
  end

  def destroy!
    @connection = nil
  end

  private
  # Recursively find attack target
  def make_attack(opponent, attacker, opponent_unit_id)
    # opponent_unit_id user only for share out attack to
    # opponent units. Don't affect buildings.
    opponent_unit = opponent.units_pool[opponent_unit_id]
    if opponent_unit.nil? == false
      [:melee_attack, :range_attack].each do |type|
        # has target for opponent unit with current opponent_unit_id
        if attacker.attack?(opponent_unit.position, type)
          attacker.attack(opponent_unit, type)
          return opponent_unit_id
        end
      end
      # If target not found, and opponent_unit_id is zero
      # Try to find target from nearest units
      unless opponent_unit_id == 0
        return make_attack(opponent, attacker, 0)
      end
    elsif opponent_unit.nil? and opponent_unit_id != 0
      # If unit at opponent_unit_id nol exist
      # and opponent_unit_id == 0
      # Try to find target from nearest units
      return make_attack(opponent, attacker, 0)
    end
    # At last check unit attack opponent main bulding
    [:melee_attack, :range_attack].each do |type|
      if attacker.attack?(opponent.main_building.position, type)
        attacker.attack(opponent.main_building, type)
      end
    end
    # Always retur current opponent id
    return opponent_unit_id
  end
end