module Damage
  class MessageType
    def initialize(type_node)
      @node = type_node
    end

    def msgtype_code
      @node.attribute('msgtype').value
    end
  end
end
