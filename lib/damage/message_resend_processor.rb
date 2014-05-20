module Damage
  class MessageResendProcessor
    attr_accessor :messages, :headers, :schema, :options

    def initialize(messages, headers, schema, options={})
      self.messages = messages
      self.headers = headers.except('MsgSeqNum')
      self.schema = schema
      self.options = options
    end

    def message_type(params)
      type_key = params.delete("MsgType")
      schema.msg_name(type_key)
    end

    def send_reset_instead?(type)
      ["Logon", "Logout", "Heartbeat", "ResendRequest"].include?(type)
    end

    def new_messages
      self.messages.map do |params|
        type = message_type(params)
        if send_reset_instead?(type)
          seq_num = params["MsgSeqNum"].to_i
          new_params = {}
          new_params["MsgSeqNum"] = seq_num
          new_params["GapFillFlag"] = true
          new_params["NewSeqNo"] = seq_num + 1
          new_params["PossDupFlag"] = true
          Message.new(schema, "SequenceReset", headers, new_params, options)
        else
          params["PossDupFlag"] = true
          Message.new(schema, type, headers, params, options)
        end
      end
    end

    def reduced_messages
      reduce_messages(new_messages)
    end

    def reduce_messages(messages)
      reduced = []
      messages.each do |message|
        prev = reduced.last
        if reduced.empty? || message.type != "4" || (prev && prev.properties["NewSeqNo"] != message.properties["MsgSeqNum"])
          reduced << message
        else
          prev.properties["NewSeqNo"] = message.properties["NewSeqNo"]
        end
      end

      reduced
    end
  end
end
