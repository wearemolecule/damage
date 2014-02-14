module Damage
  class Schema
    def initialize(schema_path)
      schema = File.dirname(__FILE__) + "/" + schema_path
      raise StandardError, "cannot find schema file" if !File.exists?(schema)

      @document = Nokogiri::XML.parse(File.open(schema))
    end

    def fields
      @fields ||= @document.xpath('//fields')[0]
    end

    def field_name(number)
      field = fields.xpath("field[@number='#{number}']")[0]
      return "Unknown#{number}" unless field
      field.attribute('name').value
    end

    def field_number(name)
      if match = name.match(/Unknown(\d*)/)
        match[1]
      else
        field = fields.xpath("field[@name='#{name}']")[0]
        raise UnknownFieldNameError, "couldn't find #{name}" unless field
        field.attribute('number').value
      end
    end

    def field_type(number)
      field = fields.xpath("field[@number='#{number}']")[0]
      return "STRING" unless field
      field.attribute('type').value
    end

    def msg_name(msg_type)
      field = @document.xpath("//messages/message[@msgtype='#{msg_type}']")[0]
      raise UnknownMessageTypeError unless field
      field.attribute('name').value
    end

    def msg_type(msg_name)
      MessageType.new(@document.xpath("//messages/message[@name='#{msg_name}']")[0])
    end

    def begin_string
      fix_root = @document.xpath('fix')[0]
      major = fix_root.attribute("major").value
      minor = fix_root.attribute("minor").value
      "FIX.#{major}.#{minor}"
    end
  end
end
