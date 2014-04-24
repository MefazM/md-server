module Networking
  MESSAGE_START_TOKEN = '__JSON__START__'
  MESSAGE_END_TOKEN = '__JSON__END__'
  TOKEN_START_LENGTH = MESSAGE_START_TOKEN.length

  module Actions
    RECEIVE_PLAYER_ACTION = :player
    RECEIVE_NEW_BATTLE_ACTION = :new_battle
    RECEIVE_BATTLE_START_ACTION = :battle_start
    RECEIVE_LOBBY_DATA_ACTION = :lobby_data
    RECEIVE_SPAWN_UNIT_ACTION = :spawn_unit
    RECEIVE_UNIT_PRODUCTION_TASK_ACTION = :unit_production_task
    RECEIVE_SPELL_CAST_ACTION = :spell_cast
    RECEIVE_RESPONSE_BATTLE_INVITE_ACTION = :response_battle_invite
    RECEIVE_PING_ACTION = :ping
    RECEIVE_BUILDING_PRODUCTION_TASK_ACTION = :building_production_task
    RECEIVE_DO_HARVESTING_ACTION = :do_harvesting
    RECEIVE_REQUEST_CURRENT_MINE_AMOUNT = :current_mine

    SEND_SPELL_CAST_ACTION = :spell_cast
    SEND_SPAWN_UNIT_ACTION = :spawn_unit
    SEND_BATTLE_SYNC_ACTION = :battle_sync
    # SEND_START_BATTLE_ACTION = :start_battle
    SEND_FINISH_BATTLE_ACTION = :finish_battle
    # SEND_REQUEST_NEW_BATTLE_ACTION = :request_new_battle
    SEND_GAME_DATA_ACTION = :game_data
    SEND_INVITE_TO_BATTLE_ACTION = :invite_to_battle
    SEND_LOBBY_DATA_ACTION = :lobby_data
    SEND_PUSH_UNIT_QUEUE_ACTION = :push_unit_queue
    SEND_START_TASK_IN_UNIT_QUEUE_ACTION = :start_task_in_unit_queue
    SEND_SYNC_BUILDING_STATE_ACTION = :sync_building_state
    SEND_CREATE_NEW_BATTLE_ON_CLIENT_ACTION = :create_new_battle_on_client
    SEND_HARVESTING_RESULTS_ACTION = :harvesting_results

    SEND_PING_ACTION = :ping
    SEND_CUSTOM_EVENT = :custom
  end

  class Request

    def initialize socket
      @socket = socket
    end

    def listen_socket
      raise "Socket is dead!" if @socket.nil?
      raise "No block given!" unless block_given?

      begin
        data_str = @socket.readpartial(4096)

        str_start = data_str.index(MESSAGE_START_TOKEN)
        str_end = data_str.index(MESSAGE_END_TOKEN)
        data = nil

        if str_start and str_end
          json = data_str[ str_start + TOKEN_START_LENGTH .. str_end - 1 ]
          action, *data = JSON.parse(json, :symbolize_names => true)
        end

      end until yield( action.to_sym, data )

    end

  end
end
