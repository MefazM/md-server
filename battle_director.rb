require "securerandom"
require 'pry'
require_relative 'ai_player.rb'
require_relative 'battle_unit.rb'
require_relative 'battle_building.rb'
require_relative 'spells_lib.rb'

# Holds all battle logic and process all battle events.
class BattleDirector
  # Battle director statuses
  PENDING = 1
  READY_TO_START = 2
  IN_PROGRESS = 3
  FINISHED = 4
  # Timings
  DEFAULT_UNITS_SPAWN_TIME = 5.0

  attr_accessor :status

  def initialize()
    # Battle director save two players connection
    # Here stores connections and battle data
    @opponents = {}
    @status = PENDING
    @opponents_indexes = {}
    @iteration_time = Time.now.to_f

    @default_unit_spawn_time = 0

    MageLogger.instance.info "New BattleDirector initialize... UID = #{@uid}"
  end

  def set_opponent(data, connection)
    player_id = data[:id]
    # Units data, available and lost
    units = {}
    data[:units].each do |uid, count|
      units[uid] = {
        :available => count,
        :lost => 0
      }
    end

    opponent_data = {
      :units => units,
      :is_ready => false,
      :units_pool => [],
      :main_building => BattleBuilding.new( 'building_1', 0.1 ),
      :spells => [],
      :connection => connection
    }

    if connection.nil?
      opponent_data[:is_ai] = true
      opponent_data[:is_ready] = true
    end

    @opponents[player_id] = opponent_data

    MageLogger.instance.info "BattleDirector (UID=#{@uid}) added opponent. ID = #{player_id}"
    # Create battle on devices if anough players
    create_battle_at_clients() if @opponents.count == 2
  end

  # After initialization battle on clients.
  # Battle starts after all opponents are ready.
  def set_opponent_ready(player_id)
    MageLogger.instance.info "BattleDirector (UID=#{@uid}) opponent ID = #{player_id} is ready to battle."
    @opponents[player_id][:is_ready] = true
    if (ready_to_start?)
      start()
    end
  end

  def is_started?()
    @status == IN_PROGRESS
  end
  # Update:
  # 1. Calculating latency
  # 2. Calculating units moverment, damage and states.
  # 3. Calculating outer effects (user spels, ...)
  # 4. Default units spawn.
  def update_opponents(current_time)
    #
    # World update
    iteration_delta = current_time - @iteration_time
    @iteration_time = current_time

    # Default unit spawn
    is_default_unit_spawn_time = current_time - @default_unit_spawn_time > DEFAULT_UNITS_SPAWN_TIME
    @default_unit_spawn_time = current_time if is_default_unit_spawn_time

    @opponents.each do |player_id, player|
      opponent_uid = @opponents_indexes[player_id]
      opponent = @opponents[opponent_uid]
      # First need to sort opponent units by distance
      opponent[:units_pool].sort_by!{|v| v.position}.reverse!

      sync_data_arr = []
      # To prevent units attack one opponent unit, and share out attacks
      # use opponent_unit_id, it will itereate after each unit attack
      # and become zero if attack is not possible
      opponent_unit_id = 0
      # update each unit and collect unit response
      player[:units_pool].each_with_index do |unit, index|
        # Unit state allow attacks?
        if unit.can_attack?
          opponent_unit_id = make_attack(opponent, unit, opponent_unit_id)
        end
        # collect updates only if unit has change
        if unit.update(iteration_delta)
          sync_data_arr << unit.sync_data()
        end

        if unit.dead?
          # Iterate lost unit counter
          unit_data = player[:units][unit.name]
          unless unit_data.nil?
            unit_data[:lost] += 1
          end

          player[:units_pool].delete_at(index)
          unit = nil
        end
      end
      # Main building - is a main game trigger.
      # If it destroyed - player loses
      main_building = player[:main_building]
      main_building.update(iteration_delta)
      # Send main bulding updates only if has changes
      if main_building.changed?
        sync_data_arr << [main_building.uid(), main_building.health_points()]
      end

      if main_building.dead?
        # finish battle, current player loses
        finish_battle(player_id)
        return
      else
        unless sync_data_arr.empty?
          # Send updated data to clients
          @opponents.each_value { |opponent|
            opponent[:connection].send_battle_sync(
              sync_data_arr
            ) unless opponent[:connection].nil?
          }
        end
        # Default units spawn
        unit_uid = 'crusader'
        add_unit_to_pool(player_id, unit_uid) if is_default_unit_spawn_time
        # Process spells
        player[:spells].each_with_index do |spell, index|
          if spell[:time] < @iteration_time then
            # puts('SPELL REMOVED')
            player[:spells].delete_at(index)
          end
        end
      end
      # /LOOP
    end
    # /UPDATE
  end

  # Additional units spawning. here should be a validation.
  def spawn_unit (unit_uid, player_id)
    unit_uid = unit_uid.to_sym
    #
    unit_data = @opponents[player_id][:units][unit_uid]
    unless unit_data.nil?
      if unit_data[:available] > 0
        unit_data[:available] -= 1
        add_unit_to_pool(player_id, unit_uid)
      end
    end
  end

  # Cast the spell to target area.
  # target_area - in percentage
  def cast_spell(opponent_uid, target_area, spell_uid)
    spell = Spells.instance.spell_battle_params(spell_uid.to_sym)
    unless spell.nil? # and player know this spell and has enough mana
      reaction_time = Time.now.to_f + spell[:reaction_time]
      @opponents[opponent_uid][:spells] << {
        :time => reaction_time,
        :uid => spell_uid
      }

      @opponents.each_value { |opponent|
        opponent[:connection].send_spell_cast(
          spell_uid, target_area, opponent_uid
        ) unless opponent[:connection].nil?
      }
    end
  end

private
  # Separate opponent units in different hashes.
  # each unit has uniq id, generated on spawning
  # unit uniq id is a hash key.
  def add_unit_to_pool(owner_id, unit_uid)
    unit = BattleUnit.new(unit_uid)
    @opponents[owner_id][:units_pool] << unit
    @opponents.each_value { |opponent|
      opponent[:connection].send_unit_spawning(
        unit.uid, unit_uid, owner_id
      ) unless opponent[:connection].nil?
    }
  end
  # Recursively find attack target
  def make_attack(opponent, attacker, opponent_unit_id)
    # opponent_unit_id user only for share out attack to
    # opponent units. Don't affect buildings.
    opponent_unit = opponent[:units_pool][opponent_unit_id]

    if opponent_unit.nil? == false
      [:melee_attack, :range_attack].each do |type|
        # has target for opponent unit with current opponent_unit_id
        if attacker.attack?(opponent_unit.position(), type)

          attacker.attack(opponent_unit, type)

          return opponent_unit_id
        end
      end
      # If target not found, and opponent_unit_id if zero
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
      if attacker.attack?(opponent[:main_building].position(), type)
        attacker.attack(opponent[:main_building], type)
      end
    end

    # Always retur current opponent id
    return opponent_unit_id
  end
  # Start the battle.
  def start()
    MageLogger.instance.info "BattleDirector (UID=#{@uid}) is started!"
    @status = IN_PROGRESS

    @opponents.each_value { |opponent|
      opponent[:connection].send_start_battle() unless opponent[:connection].nil?
    }

    @iteration_time = Time.now.to_f
    @default_unit_spawn_time = 0
  end

  # Battle ready to start, if each opponent is ready.
  def ready_to_start?()
    @opponents.each_value { |opponent|
      return opponent[:is_ready] unless opponent[:is_ready]
    }
    return true
  end
  # If each opponent is ready, It is a time to initialize battle on clients
  # Also here server should send all additional info about resources
  # so client can prechache them.
  def create_battle_at_clients()
    MageLogger.instance.info "BattleDirector (UID=#{@uid}) has two opponents. Initialize battle on clients."
    _opponents_indexes = []
    # Collecting each player main buildings info.
    # And brodcast this data to clients
    opponents_main_buildings = []
    @opponents.each do |player_id, opponent|
      player_building_data = opponent[:main_building].to_a
      player_building_data << player_id
      opponents_main_buildings << player_building_data
    end
    #############################################
    @opponents.each do |player_id, opponent|
      # Players indexes.
      _opponents_indexes << player_id
      # Opponent additional units info.
      unless opponent[:connection].nil?
        opponent[:connection].send_create_new_battle_on_client(
          @uid,
          opponent[:units],
          opponents_main_buildings
        )
      end
    end
    # hack to get player id by its opponent id.
    @opponents_indexes[_opponents_indexes[0]] = _opponents_indexes[1]
    @opponents_indexes[_opponents_indexes[1]] = _opponents_indexes[0]
  end
  # Simple finish battle.
  def finish_battle(loser_id)
    MageLogger.instance.info "BattleDirector (UID=#{@uid}). Battle finished, player (#{loser_id} - lose.)"
    @status = FINISHED
    @opponents.each do |player_id, opponent|
      opponent[:connection].send_finish_battle(
        loser_id
      ) unless opponent[:connection].nil?
      #
      # Sync player data, if not AI
      unless opponent[:is_ai]
        player = PlayerFactory.instance.player(player_id)
        player.sync_after_battle({
          :units => opponent[:units]
        })
      end

    end
  end
end
