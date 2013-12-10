#
# Network responder
#

module NETWORK_SEND_DATA

  REQUEST_PLAYER_ACTION = 1
  REQUEST_NEW_BATTLE_ACTION = 2
  REQUEST_BATTLE_START_ACTION = 3
  REQUEST_BATTLE_MAP_DATA_ACTION = 4
  REQUEST_SPAWN_UNIT_ACTION = 5
  REQUEST_PRODUCTION_TASK_ACTION = 6
  REQUEST_SPELL_CAST_ACTION = 7
  ACCEPT_BATTLE_ACTION = 8
  PING_ACTION = 9

  SEND_SPELL_CAST_ACTION = 101
  SEND_SPAWN_UNIT_ACTION = 102
  SEND_SYNC_ACTION = 103
  SEND_START_BATTLE_ACTION = 104
  SEND_FINISH_BATTLE_ACTION = 105
  SEND_REQUEST_NEW_BATTLE_ACTION = 106

  SEND_GAME_DATA_ACTION = 107

  SEND_INVITE_TO_BATTLE_ACTION = 108

  SEND_LOBBY_DATA_ACTION = 109

  SEND_PUSH_UNIT_QUEUE_ACTION = 110
  SEND_START_TASK_IN_UNIT_QUEUE_ACTION = 111

  def send_message(message_arr)

    # action, vars = message_arr

    # response[:action] = action

    # binding.pry

    message = "__JSON__START__#{message_arr.to_json}__JSON__END__"
    send_data(message)
  end

  def send_spell_cast(spell_uid, target_area, opponent_uid)
    message = [SEND_SPELL_CAST_ACTION, spell_uid, target_area, opponent_uid]
    send_message(message)
  end

  def send_unit_spawning(entity_uid, unit_id, owner_id)
    message = [SEND_SPAWN_UNIT_ACTION]
    message << entity_uid
    message << unit_id
    message << owner_id

    send_message(message)
  end

  def send_sync(units_sync_data_arr, buildings_sync_data_arr, player_id)
    message = [SEND_SYNC_ACTION]
    message << units_sync_data_arr
    message << buildings_sync_data_arr
    message << player_id

    send_message(message)
  end

  def send_start_battle()
    message = [SEND_START_BATTLE_ACTION]
    send_message(message)
  end

  def send_finish_battle(loser_id)
    message = [SEND_FINISH_BATTLE_ACTION]
    send_message(message)
  end

  def send_game_data(game_data_hash)
    message = [SEND_GAME_DATA_ACTION]
    message << game_data_hash

    send_message(message)
  end

  def send_invite_to_battle(battle_uid, invitation_from)
    message = [SEND_INVITE_TO_BATTLE_ACTION]
    message << battle_uid
    message << invitation_from

    send_message(message)
  end

  def send_lobby_data(players_data, ai_oppontns_data)
    message = [SEND_LOBBY_DATA_ACTION]
    message << players_data
    message << ai_oppontns_data

    send_message(message)
  end

  def send_unit_queue(unit_uid, producer_id, production_time)
    message = [SEND_PUSH_UNIT_QUEUE_ACTION]
    message << unit_uid
    message << producer_id
    message << production_time

    send_message(message)
  end

  def send_start_task_in_unit_queue(producer_id, production_time)
    message = [SEND_START_TASK_IN_UNIT_QUEUE_ACTION]
    message << producer_id
    message << production_time

    send_message(message)
  end

end
