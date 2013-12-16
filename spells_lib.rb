require 'singleton'
require 'pry'

class Spells
  include Singleton

  def initialize()

    MageLogger.instance.info "Spells| Loading spells from DB ..."
    @spells_prototypes = {}
    begin
      DBConnection.query("SELECT * FROM spells").each do |spell|
        # Convert ms to seconds
        spell[:reaction_time] *= 0.001

        @spells_prototypes[spell[:uid].to_sym] = spell
      end
    rescue Exception => e
      raise e
    end

    MageLogger.instance.info "Spells| #{@spells_prototypes.count} spell(s) - loaded."
  end

  def spell_battle_params(uid)
    @spells_prototypes[uid]
  end

end