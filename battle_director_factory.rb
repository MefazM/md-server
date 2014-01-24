class BattleDirectorFactory
  include Singleton

  INVITATION_LIFE_TIME = 15

  def initialize()
    @battles = {}
    @invites = {}
  end

  def invite(sender_id, opponent_id)
    sender = PlayerFactory.instance.get_player_by_id(sender_id)

    if sender.frozen?
      send_invitation_canceled_notification(sender_id)
      return false
    end

    sender.freeze!

    @invites[opponent_id] = [] if @invites[opponent_id].nil?
    @invites[opponent_id] << [sender_id, Time.now.to_i, SecureRandom.hex(16), false]

    return true
  end

  def opponent_response_to_invitation(player_id, token, decision)
    return false if @invites[player_id].nil? or @invites[player_id][0].nil?

    invitation = @invites[player_id][0]
    return false if invitation[2] != token
    if decision == true

      player = PlayerFactory.instance.get_player_by_id(player_id)
      player.freeze!

      @invites.delete(player_id)
    else
      cancel_invitation(player_id)
    end
  end

  def process_invitation_queue(current_time)
    # current_time = Time.now.to_i
    @invites.each do |player_id, invitations|
      invitation = invitations[0]

puts(current_time - invitation[1])
      if current_time - invitation[1] > INVITATION_LIFE_TIME
        # invitaion expired
        cancel_invitation(player_id)
        MageLogger.instance.info "Invitation #{invitation[2]} expired."
      elsif invitation[3] == false
        # invitaions is not sended
        send_invitation(player_id, invitation[0], invitation[2])
        # mark invitation as sended
        invitation[3] = true
        MageLogger.instance.info "Invitation #{invitation[2]} sended."
      end
    end
  end

  def get(uid)
    @battles[uid]
  end

  def update(current_time)
    @battles.each do |battle_uid, battle|
      case battle.status
      when BattleDirector::FINISHED

        @battles.delete(battle_uid)

      when BattleDirector::IN_PROGRESS

        battle.update_opponents(current_time)

      end
    end
  end

  private

  def cancel_invitation(player_id)
    invitation = @invites[player_id][0]
    sender_id = invitation[0]

    sender = PlayerFactory.instance.get_player_by_id(sender_id)
    sender.unfreeze!

    send_invitation_canceled_notification(sender_id)

    @invites[player_id].delete_at(0)

    @invites.delete(player_id) if @invites[player_id].empty?
  end

  def send_invitation(player_id, sender_id, token)
    connection = PlayerFactory.instance.connection(player_id)
    unless connection.nil?
      connection.send_invite_to_battle(token, sender_id)
    end
  end

  def send_invitation_canceled_notification(player_id)
    connection = PlayerFactory.instance.connection(player_id)
    unless connection.nil?
      connection.send_custom_event(:inviteCanceledNotification)
    end
  end
end