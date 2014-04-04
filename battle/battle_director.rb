require 'battle/unit'
require 'battle/ai_player'
require 'battle/building'
require 'battle/opponent'
require 'battle/unit'

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
    DEFAULT_UNITS_SPAWN_TIME = 1.0
    # TODO: adjust this parameter properly!!!
    UPDATE_PERIOD = 0.1 #== each 100 ms

    attr_reader :status, :uid, :channel

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
    end

    def cast_spell(player_id, spell_uid, horizontal_target)
      spell_data = Storage::GameData.spells_data[spell_uid.to_sym]

      if spell_data.nil?
        error "Spell (s: #{spell_uid}, from #{player_id}) not found."
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

      publish(@channel, [:sync_battle, sync_data]) unless sync_data.empty?

      # /UPDATE
    end
    # Additional units spawning.
    def spawn_unit(unit_name, player_id, validate = true)
      unit_name = unit_name.to_sym
      unit = @opponents[player_id].add_unit_to_pool(unit_name, validate)

      data = [:spawn_unit, unit.uid, unit_name, player_id, unit.path_id]

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
    def create_battle_at_clients
      info "BattleDirector| has two opponents. Initialize battle on clients."
      _opponents_indexes = []
      # Collecting each player main buildings info.
      # And brodcast this data to clients
      shared_data = []
      @opponents.each do |player_id, opponent|
        data = opponent.main_building.export
        data << player_id
        shared_data << data
        # Players indexes.
        _opponents_indexes << player_id
      end
      #############################################
      @opponents.each do |player_id, opponent|
        unless opponent.ai
          Actor["p_#{player_id}"].send_create_new_battle_on_client(opponent.units, shared_data)
        end
      end

      # hack to get player id by its opponent id.
      @opponents_indexes[_opponents_indexes[0]] = _opponents_indexes[1]
      @opponents_indexes[_opponents_indexes[1]] = _opponents_indexes[0]
    end

    private
    # Start the battle.
    def start!
      info "BattleDirector| is started!"
      @status = IN_PROGRESS
      @opponents.each_value { |opponent| opponent.start_battle! }
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

      publish(@channel, [:start_battle])
    end
    # Simple finish battle.
    def finish_battle!(loser_id)
      info "BattleDirector| Battle finished, player (#{loser_id} - lose.)"

      @default_unit_spawn_timer.cancel
      @update_timer.cancel

      @status = FINISHED

# @opponents.each do |player_id, opponent|
#   unless opponent.ai
#     Actor["p_#{player_id}"].send_create_new_battle_on_client(opponent.units, shared_data)
#   end
# end

#       publish(@channel, [:finish_battle, :units => ])

# def finish_battle!(loser_id)
#   # Sync player data, if not AI
#   unless @ai
#     player = PlayerFactory.instance.player(@id)
#     player.unfreeze!
#     player.sync_after_battle({
#       :units => @units
#     })
#     # Notificate about battle ended
#     # @connection.send_finish_battle(loser_id)
#   end
# end

# @opponents.each_value { |opponent| opponent.finish_battle!(loser_id) }
    end

    def drop_director
      puts "BattleDirector| #{@uid} dying. Status= #{@status}"
    end
  end
end