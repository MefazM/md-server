require 'battle/unit'
require 'battle/ai_player'
require 'battle/building'
require 'battle/opponent'
require 'battle/unit'
require 'battle/unit'
require 'battle/spells/spells_factory'
require 'game_statistics/statistics_methods'

module Battle
  class BattleDirector
    include Celluloid
    include Celluloid::Logger
    include Celluloid::Notifications

    @@uid_iteratior = 0
    # Battle director statuses
    PENDING = 1
    READY_TO_START = 2
    IN_PROGRESS = 3
    FINISHED = 4
    # Timings
    DEFAULT_UNITS_SPAWN_TIME = 5.0
    # TODO: adjust this parameter properly!!!
    UPDATE_PERIOD = 0.1 #== each 100 ms

    attr_reader :status, :uid, :channel, :opponents

    finalizer :drop_director
    # Battle director save two players connection
    # Here stores connections and battle data
    def initialize
      @opponents = {}
      @status = PENDING
      @opponents_indexes = {}
      @prev_iteration_time = 0

      @spells = []
      @uid = "battle_#{@@uid_iteratior}"
      @@uid_iteratior += 1

      @channel = "#{@uid}_ch"

      info "New BattleDirector initialize..."

      Actor[:statistics].async.battle_started

      Actor[@uid] = Actor.current
    end

    def cast_spell(player_id, uid, target)
      spell_data = Storage::GameData.spells_data[uid.to_sym]

      if spell_data.nil?
        error "Spell (s: #{uid}, from player with id = #{player_id}) not found."
      else

        spell = SpellFactory.create spell_data
        spell.channel = @channel

        area = spell_data[:area]
        life_time = spell.life_time * 1000

        publish(@channel, [:send_spell_cast, uid, life_time, target, player_id, area])

        if spell.friendly_targets?
          spell.set_target(target, @opponents[player_id].path_ways)
        else
          target = 1.0 - target

          opponent_uid = @opponents_indexes[player_id]
          spell.set_target(target, @opponents[opponent_uid].path_ways)
        end

        @spells << spell
      end
    end

    def set_opponent(data)
      info "BattleDirector| added opponent. ID = #{data[:id]}"
      @opponents[data[:id]] = Opponen.new data
    end

    # After initialization battle on clients.
    # Battle starts after all opponents are ready.
    def set_opponent_ready player_id
      info "BattleDirector| opponent ID = #{player_id} is ready to battle."
      @opponents[player_id].ready!
      # Autostart battle
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
    def update
      current_time = Time.now.to_f
      # World update
      iteration_delta = current_time - @prev_iteration_time
      @prev_iteration_time = current_time

      @spells.each do |spell|
        spell.update(current_time, iteration_delta)

        if spell.completed
          @spells.delete(spell)
        end
      end

      sync_data = []

      @opponents.each do |player_id, player|
        opponent_uid = @opponents_indexes[player_id]
        opponent = @opponents[opponent_uid]

        sync_data += player.update(opponent, iteration_delta)

        if player.lose?

          finish_battle!(player_id)
          return
        end
      end

      publish(@channel, [:send_battle_sync, sync_data]) unless sync_data.empty?

      # /UPDATE
    end
    # Additional units spawning.
    def spawn_unit(unit_name, player_id, validate = true)
      unit_name = unit_name.to_sym
      unit = @opponents[player_id].add_unit_to_pool(unit_name, validate)

      data = [:send_unit_spawning, unit.uid, unit_name, player_id, unit.path_id]

      publish(@channel, data) unless unit.nil?
    end
    # Destroy battle director
    def destroy
      @opponents.each_value { |opponent| opponent.destroy! }
    end

    # If each opponent is ready, It is a time to initialize battle on clients
    # Also here server should send all additional info about resources
    # so client can prechache them.
    # Create battle on devices if anough players
    def battle_initialization_data
      # Collecting each player main buildings info.
      # And brodcast this data to clients
      battle_data = {
        :shared_data => [],
        :units_data => {}
      }

      @opponents.each do |player_id, opponent|
        data = opponent.main_building.export
        data << player_id
        battle_data[:shared_data] << data

        battle_data[:units_data][player_id] = opponent.units_statistics
      end

      battle_data

    end

    def create_battle_at_clients
      info "BattleDirector| has two opponents. Initialize battle on clients."

      # hack to get player id by its opponent id.
      indexes = @opponents.keys
      @opponents_indexes[indexes[0]] = indexes[1]
      @opponents_indexes[indexes[1]] = indexes[0]

      publish(@channel, [:create_new_battle_on_client, battle_initialization_data])
    end


    private
    # Start the battle.
    def start!
      info "BattleDirector| is started!"
      @status = IN_PROGRESS

      # @opponents.each_value { |opponent| opponent.start_battle! }

      @prev_iteration_time = Time.now.to_f
      # Start timers
      @update_timer = after(UPDATE_PERIOD) {
        update

        @update_timer.reset
      }

      @default_unit_spawn_timer = after(DEFAULT_UNITS_SPAWN_TIME) {
        @opponents.each_key do |player_id|
          spawn_unit('crusader', player_id, false)
          spawn_unit('mage', player_id, false)
          spawn_unit('elf', player_id, false)
        end

        @default_unit_spawn_timer.reset
      }

      publish(@channel, [:send_custom_event, :startBattle])

      # publish(@channel, [:send_start_battle])
    end
    # Simple finish battle.
    def finish_battle!(loser_id)
      info "BattleDirector| Battle finished, player (#{loser_id} - lose.)"

      @default_unit_spawn_timer.cancel
      @update_timer.cancel

      @status = FINISHED

      data = {
        :loser_id => loser_id
      }

      @opponents.each do |player_id, opponent|
        data[player_id] = {
          :units => opponent.units_statistics
        }
      end

      publish(@channel, [:finish_battle, data])

      Actor[:statistics].async.battle_ended

      lobby = Actor[:lobby]
      # unfreez players at lobby
      lobby.async.set_players_frozen_state(@opponents_indexes[0], false)
      lobby.async.set_players_frozen_state(@opponents_indexes[1], false)

      terminate
    end

    def drop_director
      puts "BattleDirector| #{@uid} dying. Status= #{@status}"
    end
  end
end