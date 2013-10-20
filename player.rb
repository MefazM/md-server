require "securerandom"
require 'pry'

class Player
  def map_from_db(db_data)
    @id = db_data[:id]
    @email = db_data[:email]
    @username = db_data[:username]
  end

  def get_game_data()
    return {:buildings => {}, :technologies => {}, :units => {}}
  end

  def get_id()
    return @id
  end

  def to_hash()
    {:id => @id, :username => @username}
  end 

  def get_default_unit_package()
    'mage'
  end
end
