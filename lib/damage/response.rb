module Damage
  class Response
    def initialize(schema, message)
      @schema = schema
      @message = message
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
      @message.split(SOH)
    end

    def message_hash
      @message_hash ||= _message_hash_from_components
    end

    def _message_hash_from_components
      fields = message_components.map do |comp|
        key, value = comp.split("=")
        new_key = @schema.field_name(key)
        type = @schema.field_type(key)
        new_value = cast_field_value(type, value)
        [new_key, new_value]
      end
      Hash[*fields.flatten]
    end

    def message_type
      type_number = message_hash["MsgType"]
      @schema.msg_name(type_number)
    end

    def original_message
      @message
    end

    def underscored_keys
      Hash[*message_hash.map { |k,v|
        [k.underscore, v]
      }.flatten]
    end

    #easy access to properties
    def respond_to?(meth)
      key = meth.to_s.camelize
      message_hash.has_key?(key) || super
    end

    def method_missing(meth, *args, &block)
      key = meth.to_s.camelize
      if message_hash.has_key? key
        message_hash[key]
      else
        super
      end
    end
  end
end
