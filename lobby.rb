require 'battle/battle_director'
require 'battle/battle_director_ai'

class Lobby
  include Celluloid
  include Celluloid::Logger

  INVITATION_LIFE_TIME = 15
  UPDATE_PERIOD = 3

  def initialize
    @registred_players = {}
    @invites = {}

    every UPDATE_PERIOD do
      process_invitation_queue
    end

    Actor[:lobby] = Actor.current
  end

  def set_players_frozen_state(player_id, is_frozen)
    player = @registred_players["p_#{player_id}"]
    player[:frozen] = is_frozen unless player.nil?
  end

  def register(player_id, name, level)
    @registred_players["p_#{player_id}"] = {
      :id => player_id,
      :name => name,
      :level => level,
      :frozen => false
    }
  end

  def remove player_id
    @registred_players.delete "p_#{player_id}"
  end

  def players filtration_data
    lobby_data = []
    registred_players_frozen = @registred_players.dup
    registred_players_frozen.each_value do |player|
      player_id = player[:id]
      unless filtration_data[:except] == player[:id] or player[:frozen]
        lobby_data << [player[:id], player[:name]]
      end
    end

    lobby_data
  end

  def invite(sender_id, opponent_id)
    if sender_id == opponent_id
      error "Player can't invite itself! "
      return
    end

    info "New battle invite. From #{sender_id}, To: #{opponent_id}."
    # MAY BE UNSAFE!!!!
    sender = Actor["p_#{sender_id}"]

    if sender.frozen?
      sender.send_custom_event :inviteCanceledNotification
      return false
    end

    sender.freeze!
    set_players_frozen_state(sender_id, true)

    @invites[opponent_id] = [] if @invites[opponent_id].nil?
    @invites[opponent_id] << {
      :sender_id => sender_id,
      :time => Time.now.to_i,
      :token => SecureRandom.hex(5),
      :sent => false
    }

    rescue Celluloid::DeadActorError
      warn "Opponent player (#{opponent_id}) is offline!"
  end

  def create_ai_battle(sender_id, ai_preset_name)
    info "New battle AI battle. P: #{sender_id}, Ai: #{ai_preset_name}."
    # MAY BE UNSAFE!!!!
    sender = Actor["p_#{sender_id}"]

    if sender.frozen?
      info "Try to create Ai battle. But player (#{sender_id}) is frozen!"
      return false
    end

    sender.freeze!
    set_players_frozen_state(sender_id, true)

    battle_director = Battle::BattleDirectorAi.new

    sender.compute_mana_storage
    sender.attach_to_battle battle_director.uid

    battle_director.set_opponent( sender.battle_data )

    # Set AI opponent.
    ai_preset = Storage::GameData.ai_presets[ai_preset_name.to_sym]
    raise "AI battle. Wrong ai preset: #{ai_preset_name}" if ai_preset.nil?

    # Set actual ai level, depends on players level.
    ai_preset[:level] += sender.level
    ai_preset[:level] = 0 if ai_preset[:level] < 0

    battle_director.set_ai_opponent ai_preset
    battle_director.create_battle_at_clients
  end

  def opponent_response_to_invitation(player_id, token, decision)
    return if @invites[player_id].nil? or @invites[player_id].first.nil?

    invitation = @invites[player_id].first

    return if invitation[:token] != token

    # Opponent player confirm invitation
    if decision == true
      info "Battle accepted. P1: #{player_id} accepts P2(sender): #{invitation[:sender_id]}"

      battle_director = Battle::BattleDirector.new

      [player_id, invitation[:sender_id]].each do |opponent_id|

        player = Actor["p_#{opponent_id}"]
        player.freeze!
        set_players_frozen_state(opponent_id, true)

        player.compute_mana_storage
        player.attach_to_battle battle_director.uid

        battle_director.set_opponent( player.battle_data )
      end

      @invites.delete player_id

      battle_director.create_battle_at_clients

    else
      info "Battle rejected. P1: #{player_id}, P2(sender): #{invitation[:sender_id]}"
      # Opponent player reject invitaion
      cancel_invitation(player_id, invitation[:token])
    end
  end

  private

  def process_invitation_queue
    invites_frozen = @invites.dup
    current_time = Time.now.to_i

    invites_frozen.each do |player_id, invitations|

      next if invitations.empty?

      invitation = invitations.first

      token = invitation[:token]
      sender_id = invitation[:sender_id]

      if current_time - invitation[:time] > INVITATION_LIFE_TIME
        # invitaion expired
        cancel_invitation(player_id, token)
        info "Invitation P:(sender) #{player_id}, T:#{token} expired."
      elsif invitation[:sent] == false
        # invitaions is not sended
        begin

          Actor["p_#{player_id}"].async.send_invite_to_battle(token, sender_id)

        rescue Celluloid::DeadActorError
          warn "Try to access dead actor (p_#{sender_id})!"
        end
        # mark invitation as sended
        invitation[:sent] = true
        info "Invitation P:(sender) #{player_id}, T:#{token} sended."
      end
    end

  end

  def cancel_invitation(player_id, token)
    invitation = @invites[player_id].find{|i| i[:token] == token}

    unless invitation.nil?

      @invites[player_id].delete invitation

      sender_id = invitation[:sender_id]
      info "Invitation canceled P:(sender) #{sender_id}, T:#{invitation[:token]}."

      sender = Actor["p_#{sender_id}"]
      sender.async.unfreeze!
      set_players_frozen_state(sender_id, false)

      sender.async.send_custom_event :inviteCanceledNotification
    end

    rescue Celluloid::DeadActorError
      warn "Try to access dead actor (p_#{sender_id})!"
  end

end
