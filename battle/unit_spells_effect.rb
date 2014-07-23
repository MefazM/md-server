module Battle
  module UnitSpellsEffect

    def affect(key, options)
      unless key.nil?
        unless @affected_spells[key].nil?
          return false
        end

        @affected_spells[key] = options
      end

      options.each do |option|
        next if option[:type].nil?

        var = instance_variable_get("@#{option[:var]}")

        unless var.nil?
          option[:saved] = option[:percentage] ? var * option[:val] : option[:val]

          case option[:type]
          when :add
            var += option[:saved]
          when :reduce
            var -= option[:saved]
          end

          instance_variable_set("@#{option[:var]}", var)
        end
      end

      @force_sync = true

    end

    def remove_effect key
      return false if @affected_spells[key].nil?

      @affected_spells[key].each do |option|
        next if option[:saved].nil?

        var = instance_variable_get("@#{option[:var]}")

        unless var.nil?

          case option[:type]
          when :add
            var -= option[:saved]
          when :reduce
            var += option[:saved]
          end

          instance_variable_set("@#{option[:var]}", var)
        end
      end

      @force_sync = true
    end

  end
end