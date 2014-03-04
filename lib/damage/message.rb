module Damage
  class Message
    attr_accessor :schema, :type, :properties

    def initialize(schema, type, headers, properties)
      @schema = schema
      @type = schema.msg_type(type)
      @headers = headers
      @properties = properties
    end

    def headers
      @headers.merge({
        'SendingTime' => Time.new.utc
      })
    end

    def fixify(hash)
      hash.map { |k,v|
        num = @schema.field_number(k)
        type = @schema.field_type(num)
        if type == "BOOLEAN"
          val = v ? "Y" : "N"
        elsif type == "UTCTIMESTAMP"
          val = v.strftime('%Y%m%d-%H:%M:%S.%3N')
        else
          val = v
        end

        "#{num}=#{val}"
      }
    end

    def body
      @body ||= ["35=#{type}", fixify(headers), fixify(properties)].flatten.join(SOH) + SOH
    end

    def first_fields
      "8=#{@schema.begin_string}" + SOH + "9=#{body.length}" + SOH
    end

    def message_without_checksum
      first_fields + body
    end

    def checksum(str)
      i = 0
      str.each_byte do |b|
        i += b# unless b == 1
      end
      checksum = (i % 256).to_s.rjust(3, '0')
      "10=#{checksum}" + SOH
    end

    def full_message
      message_without_checksum + checksum(message_without_checksum)
    end

    def to_s
      "#{type}: #{properties.to_s}"
    end
  end
end
