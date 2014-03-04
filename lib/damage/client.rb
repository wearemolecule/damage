module Damage
  class Client
    include Celluloid::IO
    include Celluloid::Logger
    finalizer :shut_down

    BUFFER_SIZE = 4096
    REMOTE_LOSS_TOLERANCE = 2

    attr_accessor :heartbeat_timer, :socket, :listeners, :config,
      :options, :persistence, :schema, :logged_out, :last_remote_heartbeat,
      :heartbeat_interval
    attr_reader :test_request_sent

    def default_headers
      {
        'SenderCompID' => options[:sender_id],
        'TargetCompID' => options[:target_id],
        'MsgSeqNum'    => @msg_seq_num
      }
    end

    def initialize(listeners, options={})
      self.config = Damage.configuration
      self.options = options
      self.schema = Schema.new("schemas/#{options[:schema] || "TTFIX42"}.xml")
      extra_persistence_options = options[:extra_persistence_options] || {}
      self.persistence = config.persistence_class.new(config.persistence_options.merge(extra_persistence_options))
      self.socket = TCPSocket.new(options[:server_ip], options[:port])
      @msg_seq_num = self.persistence.current_sent_seq_num
      self.heartbeat_interval = config.heartbeat_int.to_i
      self.heartbeat_timer = every(self.heartbeat_interval) { async.send_heartbeat }
      self.last_remote_heartbeat = Time.now
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
      responses = ResponseExtractor.new(@schema, data).responses
      responses.each do |response|
        persistence.persist_rcvd(response)
        async.message_processor(response)
      end

    rescue IOError, Errno::EBADF, Errno::ECONNRESET
      info "Connection Closed"
      raise FixSocketClosedError, "socket was closed on us"
    rescue Errno::ETIMEDOUT
      #no biggie, keep listening
    end

    def message_processor(response)
      self.last_remote_heartbeat = Time.now

      message_type = response.message_type
      info "#{message_type} Received: #{response.message_hash}"
      case message_type
      when "TestRequest"
        async.send_heartbeat(response.test_request_i_d)
      when "Logon"
        #successful logon - request any missing messages
        self.logged_out = false
        async.request_missing_messages
      when "Logout"
        self.logged_out = true
        self.terminate
      when "ResendRequest"
        async.resend_requests(response)
      else
        if listeners.has_key?(message_type)
          begin
            processor = listeners[message_type].new
            processor.process(response, options)
          rescue StandardError => e
            info e
            info e.backtrace
          end
        end
      end
    rescue UnknownMessageTypeError
      info "Received unknown message #{response.message_hash}"
    end

    def setup_listeners(listener_classes)
      @listeners = Hash[*listener_classes.map { |l| [l.fix_message_name, l] }.flatten]
    end

    def time_since(start)
      start ? (Time.now - start).to_i : 0
    end

    def time_since_test_request
      time_since(self.test_request_sent)
    end

    def time_since_heartbeat
      time_since(self.last_remote_heartbeat)
    end

    def above_loss_tolerance(time_since)
      time_since >= REMOTE_LOSS_TOLERANCE * self.heartbeat_interval
    end

    def check_if_remote_alive
      if above_loss_tolerance(time_since_test_request)
        return self.terminate
      end
      if above_loss_tolerance(time_since_heartbeat)
        self.send_test_request
      end
    end

    def send_test_request
      @test_request_sent = Time.now
      params = {"TestReqID" => @test_request_sent}
      message_str = Message.new(@schema, "TestRequest", default_headers, params).full_message
      info "Sending TestRequest:"
      send_message(@socket, message_str)
    end

    def send_logon
      params = {
        'EncryptMethod' => "0",
        'HeartBtInt' => config.heartbeat_int.to_s,
        'RawData' => options[:password],
        'ResetSeqNumFlag' => !config.persistent
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

    def resend_requests(request)
      messages_to_resend = persistence.messages_to_resend(request.begin_seq_no, request.end_seq_no)
      messages = MessageResendProcessor.new(messages_to_resend, default_headers, schema).reduced_messages
      messages.each do |message|
        send_message(@socket, message.full_message, true)
      end
    end

    def send_heartbeat(request_id = nil)
      params = if request_id.nil?
                 {}
               else
                 {'TestReqID' => request_id}
               end
      message_str = Message.new(@schema, "Heartbeat", default_headers, params).full_message
      info "Sending Heartbeat"
      send_message(@socket, message_str)

      check_if_remote_alive
    end

    def graceful_shutdown!
      send_logout if @socket
    rescue Errno::EPIPE
      shut_down
    end

    def shut_down
      info "Shutting down..."
    ensure
      @listening = false
      @heartbeat_timer.try(:cancel)
      @socket.try(:close)
    end
  end

end
