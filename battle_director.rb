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
  PING_TIME = 0.5

  def initialize()
    # Battle director save two players connection
    # Here stores connections and battle data
    @opponents = {}
    @status = PENDING
    @uid = SecureRandom.hex(5)

    @opponents_indexes = {}
    @iteration_time = Time.now.to_f
    @ping_time = Time.now.to_f

    @default_unit_spawn_time = 0

    MageLogger.instance.info "New BattleDirector initialize... UID = #{@uid}"
  end

  def status
    @status
  end
  # Add player opponent snapshot and his connection.
  # If opponents > 2 - start the battle
  # :player - should contains all battle data. Refactor this shit.
  # Use this method when other play accept battle.
  def set_opponent(connection, player)
    player_id = player.get_id()

    @opponents[player_id] = {
      :connection => connection,
      :player => player,
      :is_ready => false,
      :units_pool => [],
      :main_building => nil,
      :spells => []
    }
    MageLogger.instance.info "BattleDirector (UID=#{@uid}) added opponent. ID = #{player_id}"
    # Если достаточное количество игроков чтобы начать бой
    create_battle_at_clients() if @opponents.count == 2
  end

  # Enable AI and start the battle.
  # Opponent should be added first.
  # :player - ai player object
  def enable_ai(ai_uid)
    MageLogger.instance.info "BattleDirector (UID=#{@uid}) enable AI. UID = #{ai_uid} "

    @opponents[ai_uid] = {
      :connection => nil,
      :player => AiPlayer.new(),
      :is_ready => true,
      :units_pool => [],
      :main_building => nil,
      :spells => []
    }
    create_battle_at_clients()
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
  # Battle uid.
  def uid()
    @uid
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

    # Ping update
    is_ping_time = current_time - @ping_time > PING_TIME
    @ping_time = current_time if is_ping_time

    is_ping_time  = false

    # update(iteration_delta)
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

        unit_status = unit.status
        # Unit state allow attacks?
        if unit.can_attack?
          opponent_unit_id = find_attack(opponent, unit, opponent_unit_id)
        end
        #
        unit.update(iteration_delta)
        # collect updates only if unit status change
        if (unit_status != unit.status and unit.status != 42)
          sync_data_arr << [unit.uid(), unit.status(), unit.position.round(3)]
        end

        if unit.dead?
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
        # finish battle, current player is a loser!
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
        unit_package = 'crusader'
        add_unit_to_pool(player_id, unit_package) if is_default_unit_spawn_time
        # Process spells
        player[:spells].each_with_index do |spell, index|
          if spell[:time] < @iteration_time then
            puts('SPELL REMOVED')
            player[:spells].delete_at(index)
          end
        end
        # Ping update
        @opponents.each_value { |opponent|
          opponent[:connection].send_ping(
            current_time
          ) unless opponent[:connection].nil?
        } if is_ping_time
      end
      # /LOOP
    end
    # /update
  end

  # Additional units spawning. here should be a validation.
  def spawn_unit (unit_uid, player_id)
    add_unit_to_pool(player_id, unit_uid)
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
  def find_attack(opponent, attacker, opponent_unit_id)
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
        return find_attack(opponent, attacker, 0)

      end
    elsif opponent_unit.nil? and opponent_unit_id != 0
      # If unit at opponent_unit_id nol exist
      # and opponent_unit_id == 0
      # Try to find target from nearest units
      return find_attack(opponent, attacker, 0)
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
    @ping_time = Time.now.to_f
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
    opponents_main_buildings = []

    @opponents.each do |player_id, opponent|
      player_building = BattleBuilding.new( 'building_1', 0.1 )
      opponent[:main_building] = player_building

      player_building_data = player_building.to_a
      player_building_data << player_id

      opponents_main_buildings << player_building_data
    end
    #
    @opponents.each do |player_id, opponent|
      # Players indexes.
      _opponents_indexes << player_id
      # Opponent additional units info.
      player_units = opponent[:player].get_units_data_for_battle()
      unless opponent[:connection].nil?
        opponent[:connection].send_create_new_battle_on_client(
          @uid, player_units, opponents_main_buildings
        )
      end
    end
    # hack to get user id by its opponent id.
    @opponents_indexes[_opponents_indexes[0]] = _opponents_indexes[1]
    @opponents_indexes[_opponents_indexes[1]] = _opponents_indexes[0]
  end
  # Simple finish battle.
  def finish_battle(loser_id)
    MageLogger.instance.info "BattleDirector (UID=#{@uid}). Battle finished, player (#{loser_id} - lose.)"
    @status = FINISHED
    @opponents.each_value { |opponent|
      opponent[:connection].send_finish_battle(
        loser_id
      ) unless opponent[:connection].nil?
    }
  end
end
