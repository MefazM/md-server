require 'battle/ai_player'
require 'battle/battle_director'

class Lobby
  include Celluloid
  include Celluloid::Logger

  INVITATION_LIFE_TIME = 15
  UPDATE_PERIOD = 1

  def initialize
    @registred_players = {}
    @invites = {}

    every UPDATE_PERIOD do
      process_invitation_queue
    end
  end

  def register(player_id, name)
    @registred_players["p_#{player_id}"] = {
      :id => player_id,
      :name => name
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
      frozen = Actor["p_#{player_id}"].frozen?

      lobby_data << [player[:id], player[:name]] unless filtration_data[:except] == player_id and frozen
    end

    lobby_data
  end

  def invite(sender_id, opponent_id)
    info "New battle invite. From #{sender_id}, To: #{opponent_id}."
    # MAY BE UNSAFE!!!!
    sender = Actor["p_#{sender_id}"]

    if sender.frozen?
      sender.send_custom_event(:inviteCanceledNotification)
      return false
    end

    sender.freeze!

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

  def create_ai_battle(sender_id, ai_id)
    info "New battle AI battle. P: #{sender_id}, Ai: #{ai_id}."
    # MAY BE UNSAFE!!!!
    sender = Actor["p_#{sender_id}"]

    if sender.frozen?
      info "Try to create Ai battle. But player (#{sender_id}) is frozen!"
      return false
    end

    sender.freeze!

    battle_director = Battle::BattleDirector.new()
    # Actor["battle_#{battle_director.uid}"] = battle_director

    sender.attach_to_battle battle_director.uid

    battle_director.set_opponent({
      :id => sender_id,
      :units => sender.units(),
      # Here will be other player options
    })

    # Set AI opponent
    battle_director.set_opponent({
      :id => ai_id,
      :units => Battle::AiPlayer.new.units(),
      :is_ai => true
    })

    battle_director.create_battle_at_clients

  end

  def opponent_response_to_invitation(player_id, token, decision)
    return if @invites[player_id].nil? or @invites[player_id].first.nil?

    invitation = @invites[player_id].first

    return if invitation[:token] != token

    # Opponent player confirm invitation
    if decision == true
      info "Battle accepted. P1: #{player_id} accepts P2(sender): #{invitation[:sender_id]}"

      battle_director = Battle::BattleDirector.new()

      [player_id, invitation[:sender_id]].each do |opponent_id|

        player = Actor["p_#{opponent_id}"]
        player.freeze!
        player.attach_to_battle battle_director.uid

        battle_director.set_opponent({
          :id => opponent_id,
          :units => player.units
        })

      end

      @invites.delete(player_id)

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

    invites_frozen.each do |player_id, invitations|
      invitation = invitations.first
      current_time = Time.now.to_i

      token = invitation[:token]
      sender_id = invitation[:sender_id]

      if current_time - invitation[:time] > INVITATION_LIFE_TIME
        # invitaion expired
        cancel_invitation(player_id, token)
        info "Invitation P:(sender) #{player_id}, T:#{token} expired."
      elsif invitation[:sent] == false
        # invitaions is not sended
        begin
          Actor["p_#{player_id}"].send_invite_to_battle(token, sender_id)
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

      # MAY BE UNSAFE!!!!
      sender = Actor["p_#{sender_id}"]
      sender.unfreeze!
      sender.send_custom_event(:inviteCanceledNotification)

    end



    # @invites[player_id].delete invitation
    # @invites.delete(player_id) if @invites[player_id].empty?

    rescue Celluloid::DeadActorError
      warn "Try to access dead actor (p_#{sender_id})!"
  end

end
