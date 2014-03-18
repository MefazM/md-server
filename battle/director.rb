require_relative 'ai_player.rb'
require_relative 'unit.rb'
require_relative 'building.rb'
require_relative 'opponent.rb'
require_relative 'spells/spells_factory.rb'

# Holds all battle logic and process all battle events.
class BattleDirector
  # Battle director statuses
  PENDING = 1
  READY_TO_START = 2
  IN_PROGRESS = 3
  FINISHED = 4
  # Timings
  DEFAULT_UNITS_SPAWN_TIME = 1.0
  attr_reader :status
  # Battle director save two players connection
  # Here stores connections and battle data
  def initialize
    @opponents = {}
    @status = PENDING
    @opponents_indexes = {}
    @iteration_time = 0
    @default_unit_spawn_time = 0
    @spells_data = GameData.instance.spells_data

    @spells = []

    MageLogger.instance.info "New BattleDirector initialize..."
    # ObjectSpace.define_finalizer(self, self.class.method(:finalize).to_proc)
  end

  def self.finalize(id)
    puts "BattleDirector| #{id} dying at #{Time.new}"
  end

  def cast_spell(player_id, spell_uid, horizontal_target)
    spell_data = @spells_data[spell_uid.to_sym]

    if spell_data.nil?
      MageLogger.instance.error("Spell not found.")
    else
      brodcast_custom_event = Proc.new do |name, data|
        @opponents.each_value { |opponent|
          opponent.send_custom_event!(name, data)
        }
      end

      spell = SpellFactory.create(spell_data, brodcast_custom_event)

      @opponents.each_value { |opponent|
        opponent.send_spell_cast!(spell_uid, spell.life_time * 1000,
          horizontal_target, player_id, spell_data[:area])
      }

      if spell.friendly_targets?
        spell.set_target(horizontal_target, @opponents[player_id].path_ways)
      else
        horizontal_target = 1.0 - horizontal_target

        opponent_uid = @opponents_indexes[player_id]
        spell.set_target(horizontal_target, @opponents[opponent_uid].path_ways)
      end

      @spells << spell
    end
  end

  def set_opponent(data, connection)
    MageLogger.instance.info "BattleDirector| added opponent. ID = #{data[:id]}"
    @opponents[data[:id]] = Opponen.new(data, connection)
    # Create battle on devices if anough players
    create_battle_at_clients if @opponents.count == 2
  end
  # After initialization battle on clients.
  # Battle starts after all opponents are ready.
  def set_opponent_ready(player_id)
    MageLogger.instance.info "BattleDirector| opponent ID = #{player_id} is ready to battle."
    @opponents[player_id].ready!
    # Battle ready to start, if each opponent is ready.
    all_ready = @opponents.values.all? {|opponent| opponent.ready?}
    if all_ready
      start!
    end
  end
  # Update:
  # 1. Calculating units moverment, damage and states.
  # 2. Calculating outer effects (user spels, ...)
  # 3. Default units spawn.
  def update_opponents(current_time)
    # World update
    iteration_delta = current_time - @iteration_time
    @iteration_time = current_time
    # Default units spawn time
    default_units_spawn_time = current_time - @default_unit_spawn_time > DEFAULT_UNITS_SPAWN_TIME
    if default_units_spawn_time
      @default_unit_spawn_time = current_time
    end

    @spells.each do |spell|
      spell.update!(current_time, iteration_delta)

      if spell.completed
        @spells.delete(spell)
      end
    end

    @opponents.each do |player_id, player|
      opponent_uid = @opponents_indexes[player_id]
      opponent = @opponents[opponent_uid]

      sync_data = player.update(opponent, iteration_delta)
      unless sync_data.empty?
        player.send_sync_data!(sync_data)
        opponent.send_sync_data!(sync_data)
      end

      if player.lose?
        finish_battle!(player_id)
        return
      end

      if default_units_spawn_time
        spawn_unit('crusader', player_id, false)
        spawn_unit('mage', player_id, false)
        spawn_unit('elf', player_id, false)
      end
    end
    # /UPDATE
  end
  # Additional units spawning.
  def spawn_unit(unit_name, player_id, validate = true)
    unit_name = unit_name.to_sym
    unit = @opponents[player_id].add_unit_to_pool(unit_name, validate)
    unless unit.nil?
      @opponents.each_value { |opponent|
        opponent.send_unit_spawn!(unit.uid, unit_name, player_id, unit.path_id)
      }
    end
  end
  # Destroy battle director
  def destroy
    @opponents.each_value { |opponent| opponent.destroy! }
  end

  private
  # Start the battle.
  def start!
    MageLogger.instance.info "BattleDirector| is started!"
    @status = IN_PROGRESS
    @opponents.each_value { |opponent| opponent.start_battle! }
    @iteration_time = Time.now.to_f
  end
  # If each opponent is ready, It is a time to initialize battle on clients
  # Also here server should send all additional info about resources
  # so client can prechache them.
  def create_battle_at_clients
    MageLogger.instance.info "BattleDirector| has two opponents. Initialize battle on clients."
    _opponents_indexes = []
    # Collecting each player main buildings info.
    # And brodcast this data to clients
    shared_data = []
    @opponents.each do |player_id, opponent|
      data = opponent.main_building.export
      data << player_id
      shared_data << data
    end
    #############################################
    @opponents.each do |player_id, opponent|
      # Players indexes.
      _opponents_indexes << player_id
      opponent.send_game_data!(shared_data)
    end
    # hack to get player id by its opponent id.
    @opponents_indexes[_opponents_indexes[0]] = _opponents_indexes[1]
    @opponents_indexes[_opponents_indexes[1]] = _opponents_indexes[0]
  end
  # Simple finish battle.
  def finish_battle!(loser_id)
    MageLogger.instance.info "BattleDirector| Battle finished, player (#{loser_id} - lose.)"
    @status = FINISHED
    @opponents.each_value { |opponent| opponent.finish_battle!(loser_id) }
  end
end