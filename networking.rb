module Networking
  MESSAGE_START_TOKEN = '__JSON__START__'
  MESSAGE_END_TOKEN = '__JSON__END__'
  TOKEN_START_LENGTH = MESSAGE_START_TOKEN.length

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
