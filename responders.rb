

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

end