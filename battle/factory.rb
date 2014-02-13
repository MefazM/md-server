require_relative 'director.rb'

class BattleDirectorFactory
  include Singleton

  INVITATION_LIFE_TIME = 15

  def initialize()
    @battles = {}
    @invites = {}
  end

  def invite(sender_id, opponent_id)
    sender = PlayerFactory.instance.player(sender_id)

    if sender.frozen?
      send_invitation_canceled_notification(sender_id)
      return false
    end

    sender.freeze!

    @invites[opponent_id] = [] if @invites[opponent_id].nil?
    @invites[opponent_id] << {
      :sender_id => sender_id,
      :time => Time.now.to_i,
      :token => SecureRandom.hex(5),
      :send => false,
    }

    return true
  end

  def create_ai_battle(player_id, ai_id)
    player = PlayerFactory.instance.player(player_id)
    player.freeze!

    battle_director = BattleDirector.new()
    battle_director_uid = SecureRandom.hex(5)
    @battles[battle_director_uid] = battle_director

    data = {
      :id => player_id,
      :units => player.units(),
      # Here will be other player options
    }

    connection = PlayerFactory.instance.connection(player_id)
    connection.battle_director = battle_director
    battle_director.set_opponent(data, connection)

    # Set AI opponent
    ai_player = AiPlayer.new
    data = {
      :id => ai_id,
      :units => ai_player.units(),
      # Here will be other plyer options
    }
    battle_director.set_opponent(data, nil)

    battle_director_uid
  end

  def opponent_response_to_invitation(player_id, token, decision)
    return false if @invites[player_id].nil? or @invites[player_id][0].nil?

    invitation = @invites[player_id][0]
    return false if invitation[:token] != token
    # Opponent player agree invitation
    if decision == true
      player = PlayerFactory.instance.player(player_id)
      player.freeze!
      battle_director = BattleDirector.new()
      @battles[invitation[:token]] = battle_director
      @invites.delete(player_id)

      [player_id, invitation[:sender_id]].each do |opponent_id|
        connection = PlayerFactory.instance.connection(opponent_id)
        player = PlayerFactory.instance.player(opponent_id)
        # Assign battle director to connection
        connection.battle_director = battle_director

        data = {
          :id => opponent_id,
          :units => player.units(),
          # Here will be other plyer options
        }

        battle_director.set_opponent(data, connection)
      end

      return battle_director

    else
      # Opponent player reject invitaion
      cancel_invitation(player_id)

      return nil
    end
  end

  def process_invitation_queue(current_time)
    @invites.each do |player_id, invitations|
      invitation = invitations[0]

      if current_time - invitation[:time] > INVITATION_LIFE_TIME
        # invitaion expired
        cancel_invitation(player_id)
        MageLogger.instance.info "Invitation #{invitation[:token]} expired."
      elsif invitation[:send] == false
        # invitaions is not sended
        send_invitation(player_id, invitation[:sender_id], invitation[:token])
        # mark invitation as sended
        invitation[:send] = true
        MageLogger.instance.info "Invitation #{invitation[:token]} sended."
      end
    end
  end

  def get(token)
    @battles[token]
  end

  def update(current_time)
    @battles.each do |battle_uid, battle|
      case battle.status
      when BattleDirector::FINISHED
        battle.destroy
        @battles.delete(battle_uid)

      when BattleDirector::IN_PROGRESS

        battle.update_opponents(current_time)
      end
    end

    # GC.start
  end

  private

  def cancel_invitation(player_id)
    invitation = @invites[player_id][0]
    sender_id = invitation[:sender_id]

    sender = PlayerFactory.instance.player(sender_id)
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