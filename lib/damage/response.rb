module Damage
  class Response
    attr_reader :schema, :message

    def initialize(message, options = {})
      @message = message
      @schema = options[:schema] || Damage::Schema.new(Damage::Schema::DEFAULT_SCHEMA)
    end

    def cast_field_value(type, value)
      case type.to_s
      when "INT"
        value.to_i
      when "PRICE"
        BigDecimal.new("#{value}e-2")
      when "UTCTIMESTAMP"
        tz = ActiveSupport::TimeZone["UTC"]
        tz.parse(value)
      when "BOOLEAN"
        value == "Y" ? true : false
      else
        value
      end
    end

    def message_components
      message.split(SOH)
    end

    def message_hash
      @message_hash ||= message_hash_from_components
    end

    def message_tuples_from_components
      message_components.map do |comp|
        numeric_key, raw_value = comp.split(/=/)
        keyword = schema.field_name(numeric_key)
        field_type = schema.field_type(numeric_key)
        cast_value = cast_field_value(field_type, raw_value)
        [keyword, cast_value]
      end
    end

    def message_hash_from_components
      message_tuples_from_components.inject(Hash.new) do |memo, tuple|
        key, value = tuple
        if memo.has_key?(key)
          memo[key] = [memo[key]].flatten + [value]
        else
          memo[key] = value
        end
        memo
      end
    end

    def message_type
      %r{35=([A-Z0-9]+)}i.match(message)[1]
    end

    def message_name
      type_code = %r{35=([A-Z0-9]+)}i.match(message)[1]
      schema.msg_name(type_code)
    end

    def original_message
      message
    end

    def underscored_keys
      Hash[*message_hash.map do |k,v|
        [k.underscore, v]
      end.flatten(1)]
    end

    #easy access to properties
    def respond_to?(meth)
      has_property?(method_to_property_key(meth)) || super
    end

    def method_to_property_key(meth)
      meth.to_s.camelize
    end

    def has_property?(key)
      message_hash.has_key?(key) || schema.field_names_for_message(schema.msg_name(msg_type)).include?(key)
    end

    def method_missing(meth, *args, &block)
      key = method_to_property_key(meth)
      if has_property?(key)
        message_hash[key]
      else
        super
      end
    end
  end
end
