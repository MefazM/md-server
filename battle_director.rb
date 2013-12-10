require "securerandom"
require 'pry'
require_relative 'ai_player.rb'
require_relative 'defines.rb'
require_relative 'battle_unit.rb'
require_relative 'battle_building.rb'
require_relative 'spells_lib.rb'

# Holds all battle logic and process all battle events.
class BattleDirector

  def initialize()
    # Battle director save two players connection
    # Here stores connections and battle data
    @opponents = {}

    @status = BattleStatuses::PENDING
    @uid = SecureRandom.hex(5)

    @opponents_indexes = {}
    @iteration_time = Time.now.to_f
    @ping_time = Time.now.to_f

    @default_unit_spawn_time = 0

    MageLogger.instance.info "New BattleDirector initialize... UID = #{@uid}"
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
      :units_pool => {},
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
      :units_pool => {},
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
    @status == BattleStatuses::IN_PROGRESS
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
    #
    iteration_delta = current_time - @iteration_time
    if (iteration_delta > Timings::ITERATION_TIME)
      @iteration_time = current_time
      update_opponent(iteration_delta)
    end
    # /World update

    #
    # Ping update
    #
    # if current_time - @ping_time > Timings::PING_TIME
    #   @ping_time = current_time

    #   broadcast_response({:time => current_time}, 'ping')
    # end
    # /Ping update

    #
    # Default unit spawn
    if current_time - @default_unit_spawn_time > Timings::DEFAULT_UNITS_SPAWN_TIME
      @default_unit_spawn_time = current_time
      @opponents_indexes.each do |player_index|
        # players should have different default units
        unit_package = 'crusader'
        add_unit_to_pool(player_id, unit_package)
      end
    end
    # /Default unit spawn
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
  # Send message to all opponents is this battle
  # def broadcast_response(*args)
  #   @opponents.each_value { |opponent|
  #     opponent[:connection].send_message(args) unless opponent[:connection].nil?
  #   }
  # end

  # Separate opponent units in different hashes.
  # each unit has uniq id, generated on spawning
  # unit uniq id is a hash key.
  def add_unit_to_pool(owner_id, unit_uid)
    unit = BattleUnit.new(unit_uid)
    uid = unit.get_uid()
    @opponents[owner_id][:units_pool][uid] = unit

    @opponents.each_value { |opponent|
      opponent[:connection].send_unit_spawning(
        uid, unit_uid, owner_id
      ) unless opponent[:connection].nil?
    }
  end

  def update_opponent(iteration_delta)
    @opponents.each do |player_id, player|

      opponent_uid = @opponents_indexes[player_id]
      opponent = @opponents[opponent_uid]
      units_sync_data = []
      buildings_sync_data = []
      # update each unit and collect unit response
      player[:units_pool].each do |uid, unit|
        # response[uid] = unit.update(opponent, iteration_delta)
        units_sync_data << unit.update(opponent, iteration_delta)
        player[:units_pool].delete(uid) if unit.dead?
      end
      # Main building - is a main game trigger.
      # If it destroyed - player loses
      main_building = player[:main_building]
      main_building.process_deffered_damage(iteration_delta)
      buildings_sync_data << main_building.to_a

      if main_building.dead?
        # finish battle, current player is a loser!
        finish_battle(player_id)
      end

      @opponents.each_value { |opponent|
        opponent[:connection].send_sync(
          units_sync_data, buildings_sync_data, player_id
        ) unless opponent[:connection].nil?
      }
      # process spells
      player[:spells].each_with_index do |spell, index|
        if spell[:time] < @iteration_time then
          puts('SPELL REMOVED')
          player[:spells].delete_at(index)
        end
      end

    end
  end
  # Start the battle.
  def start()
    MageLogger.instance.info "BattleDirector (UID=#{@uid}) is started!"
    @status = BattleStatuses::IN_PROGRESS

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
        opponent[:connection].send_message([
          NETWORK_SEND_DATA::SEND_REQUEST_NEW_BATTLE_ACTION,
          @uid, player_units, opponents_main_buildings
        ])
      end
    end
    # hack to get user id by its opponent id.
    @opponents_indexes[_opponents_indexes[0]] = _opponents_indexes[1]
    @opponents_indexes[_opponents_indexes[1]] = _opponents_indexes[0]
  end
  # Simple finish battle.
  # Free memory, and mark object to delete.
  def finish_battle(loser_id)
    MageLogger.instance.info "BattleDirector (UID=#{@uid}). Battle finished, player (#{loser_id} - lose."

    @status = BattleStatuses::FINISHED

    @opponents.each_value { |opponent|
      opponent[:connection].send_finish_battle(loser_id) unless opponent[:connection].nil?
    }
  end
end
