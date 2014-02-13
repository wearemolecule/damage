module Damage
  class Client
    include Celluloid::IO
    include Celluloid::Logger
    finalizer :shut_down

    HEART_BT_INT = ENV['TT_HEART_BT_INT']
    BUFFER_SIZE = 10240

    attr_accessor :heartbeat_timer, :socket, :listeners

    def default_headers
      {
        'SenderCompID' => ENV['TT_FIX_SENDER'],
        'TargetCompID' => ENV['TT_FIX_TARGET'],
        'MsgSeqNum'    => @msg_seq_num
      }
    end

    def initialize(listeners)
      @schema = Schema.new("schemas/TTFIX42.xml")
      @socket = TCPSocket.new(ENV['TT_FIX_IP'], ENV['TT_FIX_PORT'])
      @msg_seq_num = 1
      @heartbeat_timer = every(HEART_BT_INT) { async.send_heartbeat }
      @listening = true

      setup_listeners(listeners)

      send_logon
      async.run
    end

    def run
      while @listening do
        read_message(@socket)
      end
    end

    def send_message(socket, message)
      info("Wrote: #{message.gsub("\01", ", ")}")
      socket.write(message)
      @heartbeat_timer.reset
      @msg_seq_num += 1
    end

    def read_message(socket)
      data = socket.readpartial(BUFFER_SIZE)
      response = Response.new(@schema, data)
      async.message_processor(response)

    rescue IOError, Errno::EBADF, Errno::ECONNRESET
      @listening = false
      @heartbeat_timer.cancel
      info "Connection Closed"
    end

    def message_processor(response)
      message_type = response.message_type
      info "#{message_type} Received: #{response.message_hash}"
      case message_type
      when "TestRequest"
        async.send_heartbeat(response.test_request_i_d)
      else
        if listeners.has_key?(message_type)
          processor = listeners[message_type].new
          processor.async.process(response)
        else
          info "Message not handled"
        end
      end
    end

    def setup_listeners(listener_classes)
      @listeners = Hash[*listener_classes.map { |l| [l.fix_message_name, l] }.flatten]
    end

    def send_logon
      params = {
        'EncryptMethod' => "0",
        'HeartBtInt' => HEART_BT_INT.to_s,
        'RawData' => "12345678",
        'ResetSeqNumFlag' => "Y"
      }

      message_str = Message.new(@schema, "Logon", default_headers, params).full_message
      info "Sending Logon:"
      send_message(@socket, message_str)
    end

    def send_logout
      params = {
        'ForceLogout' => "0"
      }
      message_str = Message.new(@schema, "Logout", default_headers, params).full_message
      info "Sending Logout:"
      send_message(@socket, message_str)
    end

    def send_heartbeat(request_id = nil)
      params = if !request_id.nil?
                 {}
               else
                 {'TestReqID' => request_id}
               end
      message_str = Message.new(@schema, "Heartbeat", default_headers, params).full_message
      info "Sending Heartbeat"
      send_message(@socket, message_str)
    end

    def shut_down
      info "Shutting down..."
      send_logout if @socket
      @listening = false
      @heartbeat_timer.cancel
      @socket.close
    end
  end
end
