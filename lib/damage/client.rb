module Damage
  class Client
    include Celluloid::IO
    include Celluloid::Logger
    finalizer :shut_down

    BUFFER_SIZE = 10240

    attr_accessor :heartbeat_timer, :socket, :listeners, :config, :persistence, :schema

    def default_headers
      {
        'SenderCompID' => config.sender_id,
        'TargetCompID' => config.target_id,
        'MsgSeqNum'    => @msg_seq_num
      }
    end

    def initialize(listeners)
      self.config = Damage.configuration
      self.schema = Schema.new("schemas/#{config.schema}.xml")
      self.persistence = config.persistence_class.new(config.persistence_options)
      self.socket = TCPSocket.new(config.server_ip, config.port)
      @msg_seq_num = self.persistence.current_sent_seq_num
      self.heartbeat_timer = every(config.heartbeat_int.to_i) { async.send_heartbeat }
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

    def send_message(socket, message, resend = false)
      info("Wrote: #{message.gsub("\01", ", ")}")
      socket.write(message)

      if !resend
        response = Response.new(@schema, message)
        persistence.persist_sent(response)
        @msg_seq_num += 1
      end
      heartbeat_timer.try(:reset)
    end

    def read_message(socket)
      data = socket.readpartial(BUFFER_SIZE)
      response = Response.new(@schema, data)
      persistence.persist_rcvd(response)
      async.message_processor(response)

    rescue IOError, Errno::EBADF, Errno::ECONNRESET
      @listening = false
      @heartbeat_timer.try(:cancel)
      info "Connection Closed"
    rescue Errno::ETIMEDOUT
      #no biggie, keep listening
    end

    def message_processor(response)
      message_type = response.message_type
      info "#{message_type} Received: #{response.message_hash}"
      case message_type
      when "TestRequest"
        async.send_heartbeat(response.test_request_i_d)
      when "Logon"
        #successful logon - request any missing messages
        async.request_missing_messages
      when "ResendRequest"
        async.resend_requests(response)
      else
        if listeners.has_key?(message_type)
          processor = listeners[message_type].new
          processor.process(response)
        end
      end
    rescue UnknownMessageTypeError
      info "Received unknown message #{response.message_hash}"
    end

    def setup_listeners(listener_classes)
      @listeners = Hash[*listener_classes.map { |l| [l.fix_message_name, l] }.flatten]
    end

    def send_logon
      params = {
        'EncryptMethod' => "0",
        'HeartBtInt' => config.heartbeat_int.to_s,
        'RawData' => config.password,
        'ResetSeqNumFlag' => config.reset_seq_num_flag
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

    def request_missing_messages
      persistence.missing_message_ranges.each do |start, finish|
        params = {
          "BeginSeqNo" => start,
          "EndSeqNo" => finish
        }
        message_str = Message.new(@schema, "ResendRequest", default_headers, params).full_message
        info "Requesting messages #{start} through #{finish}"
        send_message(@socket, message_str)
      end
    end

    def resend_requests(message)
      persistence.messages_to_resend(message.begin_seq_no, message.end_seq_no).each do |params|
        type_key = params.delete("MsgType")
        type = @schema.msg_name(type_key)
        params["PossDupFlag"] = "Y"
        message_str = Message.new(@schema, type, default_headers.except("MsgSeqNum"), params).full_message

        send_message(@socket, message_str, true)
      end
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
    rescue Errno::EPIPE
      #socket already closed
    ensure
      @listening = false
      @heartbeat_timer.try(:cancel)
      @socket.close
    end
  end

end
