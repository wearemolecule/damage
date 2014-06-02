require 'nokogiri'

module Damage
  class Schema
    DEFAULT_SCHEMA = "schemas/FIX42.xml"

    attr_accessor :file_path, :document

    def initialize(schema_path, options = {})
      @file_path = if options[:relative] || options[:relative].nil?
                     File.join(File.dirname(__FILE__), schema_path)
                   else
                     schema_path
                   end
      raise StandardError, "cannot find schema file" if !File.exists?(@file_path)

      @document = ::Nokogiri::XML.parse(File.open(@file_path))
    end

    def groups
      @groups ||= document.xpath('//groups')[0]
    end

    def fields
      @fields ||= document.xpath('//fields')[0]
    end

    def field_name(number)
      field = fields.xpath("field[@number='#{number}']")[0]
      return "Unknown#{number}" unless field
      field.attribute('name').value
    end

    def field_number(name, strict = true)
      if match = name.match(/Unknown(\d*)/)
        match[1]
      else
        field = fields.xpath("field[@name='#{name}']")[0]
        if field
          field.attribute('number').value
        else
          if strict
            raise UnknownFieldNameError, "couldn't find #{name}"
          else
            nil
          end
        end
      end
    end

    def field_type(number)
      field = fields.xpath("field[@number='#{number}']")[0]
      return "STRING" unless field
      field.attribute('type').value
    end

    def msg_name(msg_type)
      entity = message_lookup('msgtype', msg_type)
      entity.attribute('name').value
    end

    def msg_type(msg_name)
      entity = message_lookup('name', msg_name)
      entity.attribute('msgtype').value
    end

    def header_fields
      document.xpath('//header/field')
    end

    def header_field_names
      node_names_from_nodeset(header_fields)
    end

    def required_header_fields
      required_nodes_in_nodeset(header_fields)
    end

    def required_header_field_names
      node_names_from_nodeset(required_header_fields)
    end

    def fields_for_message(name)
      message_lookup('name', name).xpath('field')
    end

    def field_names_for_message(name)
      node_names_from_nodeset(fields_for_message(name))
    end

    def required_fields_for_message(name)
      required_nodes_in_nodeset(fields_for_message(name))
    end

    def required_field_names_for_message(name)
      node_names_from_nodeset(required_fields_for_message(name))
    end

    def begin_string
      fix_root = document.xpath('fix')[0]
      major = fix_root.attribute("major").value
      minor = fix_root.attribute("minor").value
      "FIX.#{major}.#{minor}"
    end

    private
    def message_lookup(field, value)
      element = document.xpath("//messages/message[@#{field}='#{value}']")[0]
      raise UnknownMessageTypeError unless element
      element
    end

    def required_nodes_in_nodeset(nodeset)
      nodes = nodeset.select do |node|
        node.attributes.any? do |attr_name, attr_obj|
          attr_name == 'required' && attr_obj.value == 'Y'
        end
      end
      Nokogiri::XML::NodeSet.new(@document, nodes)
    end

    def node_names_from_nodeset(nodeset)
      nodeset.map do |elem|
        elem.attributes.find do |attr_name, attr_obj|
          attr_obj.name == 'name'
        end.last.value
      end
    end
  end
end
