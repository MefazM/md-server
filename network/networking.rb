module Networking
  MESSAGE_START_TOKEN = '__JSON__START__'
  MESSAGE_END_TOKEN = '__JSON__END__'
  TOKEN_START_LENGTH = MESSAGE_START_TOKEN.length

  module Actions
    RECEIVE_PLAYER_ACTION = 1
    RECEIVE_NEW_BATTLE_ACTION = 2
    RECEIVE_BATTLE_START_ACTION = 3
    RECEIVE_LOBBY_DATA_ACTION = 4
    RECEIVE_SPAWN_UNIT_ACTION = 5
    RECEIVE_UNIT_PRODUCTION_TASK_ACTION = 6
    RECEIVE_SPELL_CAST_ACTION = 7
    RECEIVE_RESPONSE_BATTLE_INVITE_ACTION = 8
    RECEIVE_PING_ACTION = 9
    RECEIVE_BUILDING_PRODUCTION_TASK_ACTION = 10
    RECEIVE_DO_HARVESTING_ACTION = 11
    RECEIVE_REQUEST_CURRENT_MINE_AMOUNT = 12

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
    SEND_HARVESTING_RESULTS_ACTION = 114

    SEND_PING_ACTION = 555
    SEND_CUSTOM_EVENT = 777
  end

  class Request

    def self.listen_socket(socket)
      raise "Socket is dead!" if socket.nil?
      raise "No block given!" unless block_given?

      begin
        data_str = socket.readpartial(4096)

        str_start = data_str.index(MESSAGE_START_TOKEN)
        str_end = data_str.index(MESSAGE_END_TOKEN)
        data = nil

        if str_start and str_end
          json = data_str[ str_start + TOKEN_START_LENGTH .. str_end - 1 ]
          action, *data = JSON.parse(json, :symbolize_names => true)
        end

      end until yield( action, data )

    end

  end
end
