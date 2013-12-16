#
# Network responder
#

module NETWORK_SEND_DATA

  RECEIVE_PLAYER_ACTION = 1
  RECEIVE_NEW_BATTLE_ACTION = 2
  RECEIVE_BATTLE_START_ACTION = 3
  RECEIVE_LOBBY_DATA_ACTION = 4
  RECEIVE_SPAWN_UNIT_ACTION = 5
  RECEIVE_UNIT_PRODUCTION_TASK_ACTION = 6
  RECEIVE_SPELL_CAST_ACTION = 7
  RECEIVE_ACCEPT_BATTLE_ACTION = 8
  RECEIVE_PING_ACTION = 9
  RECEIVE_BUILDING_PRODUCTION_TASK_ACTION = 10

  SEND_SPELL_CAST_ACTION = 101
  SEND_SPAWN_UNIT_ACTION = 102
  SEND_BATTLE_SYNC_ACTION = 103
  SEND_START_BATTLE_ACTION = 104
  SEND_FINISH_BATTLE_ACTION = 105
  # SEND_REQUEST_NEW_BATTLE_ACTION = 106
  SEND_GAME_DATA_ACTION = 107
  SEND_INVITE_TO_BATTLE_ACTION = 108
  SEND_LOBBY_DATA_ACTION = 109
  SEND_PUSH_UNIT_QUEUE_ACTION = 110
  SEND_START_TASK_IN_UNIT_QUEUE_ACTION = 111
  SEND_SYNC_BUILDING_STATE_ACTION = 112
  SEND_CREATE_NEW_BATTLE_ON_CLIENT_ACTION = 113

  SEND_PING_ACTION = 555

  def send_message(message_arr)
    puts("SEND: #{message_arr.inspect}")
    message = "__JSON__START__#{message_arr.to_json}__JSON__END__"
    send_data(message)
  end

  def send_spell_cast(spell_uid, target_area, owner_id)
    message = [SEND_SPELL_CAST_ACTION, @latency]
    message << spell_uid
    message << target_area
    message << owner_id

    send_message(message)
  end

  def send_unit_spawning(entity_uid, unit_id, owner_id)
    message = [SEND_SPAWN_UNIT_ACTION, @latency]
    message << entity_uid
    message << unit_id
    message << owner_id

    send_message(message)
  end

  def send_battle_sync(units_sync_data_arr)
    message = [SEND_BATTLE_SYNC_ACTION, @latency]
    message << units_sync_data_arr

    send_message(message)
  end

  def send_start_battle()
    message = [SEND_START_BATTLE_ACTION, @latency]
    send_message(message)
  end

  def send_finish_battle(loser_id)
    message = [SEND_FINISH_BATTLE_ACTION, @latency]
    message << loser_id

    send_message(message)
  end

  def send_game_data(game_data_hash)
    message = [SEND_GAME_DATA_ACTION, @latency]
    message << game_data_hash

    send_message(message)
  end

  def send_invite_to_battle(battle_uid, invitation_from)
    message = [SEND_INVITE_TO_BATTLE_ACTION, @latency]
    message << battle_uid
    message << invitation_from

    send_message(message)
  end

  def send_lobby_data(players_data, ai_oppontns_data)
    message = [SEND_LOBBY_DATA_ACTION, @latency]
    message << players_data
    message << ai_oppontns_data

    send_message(message)
  end

  def send_unit_queue(unit_uid, producer_id, production_time)
    message = [SEND_PUSH_UNIT_QUEUE_ACTION, @latency]
    message << unit_uid
    message << producer_id
    message << production_time

    send_message(message)
  end

  def send_start_task_in_unit_queue(producer_id, production_time)
    message = [SEND_START_TASK_IN_UNIT_QUEUE_ACTION, @latency]
    message << producer_id
    message << production_time

    send_message(message)
  end

  def send_sync_building_state(uid, level, is_ready = true, finish_time = nil)
    message = [SEND_SYNC_BUILDING_STATE_ACTION, @latency]
    message << uid
    message << level
    message << is_ready

    message << finish_time unless is_ready

    send_message(message)
  end

  def send_create_new_battle_on_client(uid, player_units, opponents_main_buildings)
    message = [SEND_CREATE_NEW_BATTLE_ON_CLIENT_ACTION, @latency]
    message << uid
    message << player_units
    message << opponents_main_buildings

    send_message(message)
  end

  def send_ping(current_time)
    message = [SEND_PING_ACTION, @latency]
    message << current_time

    send_message(message)
  end
end
