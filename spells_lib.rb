# require 'singleton'
# require 'pry'

# class Spells
#   include Singleton

#   def initialize()

#     MageLogger.instance.info "Spells| Loading spells from DB ..."
#     @spells_prototypes = {}
#     begin
#       DBConnection.query("SELECT * FROM spells").each do |spell|
#         # Convert ms to seconds
#         spell[:time_s] = spell[:time] * 0.001

#         [:uid, :ability_preset, :processing_type].each do |field|
#           spell[field] = spell[field].to_sym
#         end

#         spell[:value] = case spell[:ability_preset]
#           when :a_hp, :a_attack, :a_movement_speed
#             spell[:value].to_f
#         end

#         @spells_prototypes[spell[:uid]] = spell
#       end
#     rescue Exception => e
#       raise e
#     end

#     MageLogger.instance.info "Spells| #{@spells_prototypes.count} spell(s) - loaded."
#   end

#   def get(uid)
#     @spells_prototypes[uid]
#   end

# end