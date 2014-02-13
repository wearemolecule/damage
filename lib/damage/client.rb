module Damage
  class Client
    include Celluloid::IO
    include Celluloid::Logger
    finalizer :shut_down

    BUFFER_SIZE = 10240

    attr_accessor :heartbeat_timer, :socket, :listeners

    def default_headers
      {
        'SenderCompID' => Damage.configuration.sender_id,
        'TargetCompID' => Damage.configuration.target_id,
        'MsgSeqNum'    => @msg_seq_num
      }
    end

    def initialize(listeners)
      @schema = Schema.new("schemas/#{Damage.configuration.schema}.xml")
      @socket = TCPSocket.new(Damage.configuration.server_ip, Damage.configuration.port)
      @msg_seq_num = 1
      @heartbeat_timer = every(Damage.configuration.heartbeat_int) { async.send_heartbeat }
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
        'HeartBtInt' => Damage.configuration.heartbeat_int.to_s,
        'RawData' => Damage.configuration.password,
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
