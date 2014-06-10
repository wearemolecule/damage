module Damage
  class Message
    attr_accessor :schema, :type, :properties, :strict, :name

    def initialize(schema, name, headers, properties, options={})
      @schema = schema
      @name = name
      @type = schema.msg_type(name)
      @headers = headers
      @properties = properties
      @options = options
      @strict = options[:strict] || options[:strict].nil?
    end

    def strict?
      @strict
    end

    def headers
      @headers.merge({
        'SendingTime' => Time.new.utc
      })
    end

    # NOTE: perhaps should use ActiveRecord Validations?
    def valid?
      headers_are_valid? && properties_are_valid?
    end

    def headers_are_valid?
      # don't need to check for 'BeginString', 'BodyLength', or 'MsgType' as they're added upon generation of the FIX message itself
      all_have_values?(headers, schema.required_header_field_names - ['BeginString', 'BodyLength', 'MsgType'])
    end

    def properties_are_valid?
      all_have_values?(properties, schema.required_field_names_for_message(name))
    end

    def all_have_values?(hash, keys)
      keys.all? do |key|
        hash.has_key?(key) && !hash[key].nil?
      end
    end

    def fixify(hash)
      hash.map do |key, val|
        [val].flatten.map do |v|
          [@schema.field_number(key, strict?), v]
        end
      end.flatten(1).reject do |num, val|
        num.nil?
      end.map do |num, v|
        val = case @schema.field_type(num)
              when "BOOLEAN"
                v ? "Y" : "N"
              when "UTCTIMESTAMP"
                v.strftime('%Y%m%d-%H:%M:%S.%3N')
              else
                v
              end
        "#{num}=#{val}"
      end
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
