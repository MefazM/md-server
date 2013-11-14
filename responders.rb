

class Respond

  def self.as_building (package, level, is_ready = true, finish_time = nil, production_time = nil)
    result = {
      :level => level,
      :ready => is_ready,
      :package => package
    }
    result[:finish_time] = finish_time * 1000 unless finish_time.nil?
    result[:production_time] = production_time * 1000 unless production_time.nil?

    result
  end

  def self.as_battle_initialize_at_clients(battle_uid, units, buildings)
    {
      :battle_uid => battle_uid,
      :units => units,
      :buildings => buildings,
    }
  end

  def self.as_battle_map(appropriate_players, appropriate_ai)
    response = {}
    response[:players] = appropriate_players
    response[:ai] = [{:id => 13123, :title => 'someshit'}, {:id => 334, :title => '111min'}]

    response
  end

  def self.as_unit_produce_add(unit_uid, producer_id, produce_time)
    response = {}
    response[:unit_uid] = unit_uid
    response[:producer_id] = producer_id
    response[:produce_time] = produce_time * 1000

    response
  end

end
