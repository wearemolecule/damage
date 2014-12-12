
module Damage
  class MessageDefinition
    attr_accessor :element,
                  :group_name,
                  :schema
    hash_fields = []

    def initialize(element,group, schema)
      @element = element
      @group_name = group
      @schema = schema
    end

    def groups
      @groups ||= element.xpath('group')[0]
    end

    def group
      element.xpath("group[@name='#{group_name}']")
    end

    def group_fields
      fields = []
      group.children.each do |kid|
        if kid.name == 'component'
          fields.push(*get_component_fields(kid.attributes["name"]))
        end
        if kid.name == 'field'
          fields.push(kid.attributes['name'].value)
        end
        if kid.name == 'group'
          fields.push(*get_fields(kid, "field"))
        end
       
      end
      fields
    end

    def get_component_fields(component_name)
      fields = []
      fields = get_fields(schema, "//fix/components/component[@name='#{component_name}']/field")
      fields.push(*get_fields(schema, "//fix/components/component[@name='#{component_name}']/group/field"))
      # get for component within component
      schema.document.xpath("//fix/components/component[@name='#{component_name}']/component").each do |comp|
        fields.push(*get_component_fields(comp.attributes['name'].value))
      end
      fields
    end

    def get_fields(node, query)
      fields = []
      node.document.xpath(query).each do |kid|
        fields << kid.attributes['name'].value
      end
      fields
      
    end

  end
end
