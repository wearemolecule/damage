module Damage
  class SecurityDefinitionResponse < Response

    def message_tuples_from_components
      group_started = false
      temp_hash = nil
      md = nil
      hash_array = nil
      hash_key = nil
      component_array = []
      group_name = nil

      message_components.each do |comp|
        numeric_key, raw_value = comp.split(/=/)
        keyword = schema.field_name(numeric_key)
        field_type = schema.field_type(numeric_key)
        cast_value = cast_field_value(field_type, raw_value)

        if(field_type == "NUMINGROUP")
          group_started = true
          group_name = "#{keyword}_group"
          md = Damage::MessageDefinition.new(schema.msg("msgtype", message_type), keyword, schema)
          hash_array = []
          component_array << [keyword, cast_value]
          next
        end

        if group_started
          hash_key ||= keyword
          if hash_key == keyword
            temp_hash = {}
            hash_array << temp_hash
          end
          if md.group_fields.include? keyword
            temp_hash[keyword] = cast_value
          else
            component_array << [group_name, hash_array]
            group_started = false
          end
        else
          component_array << [keyword, cast_value]
        end
      end
      component_array
    end

    def message_hash_from_components
      message_tuples_from_components.inject(Hash.new) do |memo, tuple|
        key, value = tuple
        memo[key] = value
        memo
      end
    end

  end
end
