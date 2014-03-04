module Damage
  class ResponseExtractor
    attr_accessor :schema, :orig_buffer, :responses
    def initialize(schema, buffer)
      self.schema = schema
      self.orig_buffer = buffer

      extract_messages
    end

    def extract_messages
      self.responses = []

      buffer = orig_buffer.clone
      message_available = true
      while message_available do
        message, buffer = read_next_message(buffer)
        message_available = !!buffer && buffer.length > 0
        next if !message
        responses << Response.new(schema, message)
      end
    end

    def read_next_message(buffer)
      return [false, buffer] if buffer.length < 2

      index = buffer.index("8=")
      return [false, buffer] if index == -1

      buffer = buffer[index..-1]

      len, header_end = extract_length(buffer)

      index = buffer.index(SOH + "10=", header_end)
      return [false, buffer] if index == -1
      return [false, buffer[header_end..-1]] if len != index - header_end

      index = buffer.index(SOH, index + 1)

      [buffer[0..index], buffer[index+1..-1]]
    rescue MessageParseError
      return [false, buffer]
    rescue
      return [false, buffer]
    end

    def extract_length(buffer)
      start_pos = buffer.index(SOH + "9=")
      raise MessageParseError, "Missing message size" if start_pos == -1
      start_pos += 3
      end_pos = buffer.index(SOH, start_pos)
      raise MessageParseError, "Missing message size" if end_pos == -1

      [buffer[start_pos..end_pos].to_i, end_pos]
    end
  end
end
