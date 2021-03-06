module Damage
  class Client
    module Base
      def self.included(base)
        base.send(:include, Celluloid::IO)
        base.send(:include, Celluloid::Logger)
        base.send(:extend, ClassMethods)

        base.send(:finalizer, :shut_down)
      end

      BUFFER_SIZE = 4096
      REMOTE_LOSS_TOLERANCE = 2

      attr_accessor :heartbeat_timer,
                    :socket,
                    :listeners,
                    :config,
                    :options,
                    :persistence,
                    :schema,
                    :logged_out,
                    :logout_time,
                    :last_remote_heartbeat,
                    :heartbeat_interval,
                    :strict
      attr_reader :test_request_sent

      module ClassMethods
        # def run(listeners, options={})
        #   self.new(listeners, options)
        #   self.async.run
        # end
      end

      def initialize(listeners, options={})
        self.config = Damage.configuration
        self.options = options
        # self.schema = Schema.new("schemas/#{options[:schema] || "TTFIX42"}.xml")
        self.schema = options[:schema] || Schema.new("schemas/#{options[:schema_name] || 'TTFIX42'}.xml")
        extra_persistence_options = options[:extra_persistence_options] || {}
        self.persistence = config.persistence_class.new(config.persistence_options.merge(extra_persistence_options))
        @msg_seq_num = self.persistence.current_sent_seq_num
        self.heartbeat_interval = config.heartbeat_int.to_i
        self.last_remote_heartbeat = Time.now
        self.strict = options[:strict] || options[:strict].nil?
        @listening = true
        self.logged_out = true
        self.logout_time = nil

        self.heartbeat_timer = every(self.heartbeat_interval) do
          async.tick!
        end

        setup_listeners(listeners)
        autostart = options[:autostart] || options[:autostart].nil?
        async.run if autostart
      end

      def run
        establish_session
        while @listening do
          sleep(0.1)
          read_message(@socket)
        end
      end

      def establish_session
        t = Time.now.utc.in_time_zone("Eastern Time (US & Canada)")
        if logged_out && can_login_again?(t)
          if in_operating_window?(t) 
            _info "Establishing ICE FIX Session..."
            if @socket.nil?
              @socket = TCPSocket.new(options[:server_ip], options[:port])
            end
            @listening = true
            # logon and reset sequence number
            send_logon_and_reset
          else
            _info "DateTime #{t.to_s} is not within the operating window"
            pause_listener
          end
        end
      rescue IOError, Errno::EBADF, Errno::ECONNRESET => ex
        _info "Connection Closed"
        # wait for 20 seconds.  ICE has a 15 second throttle limit for logon requests
        sleep 20
        raise FixSocketClosedError, "socket was closed on us"
      end

      def in_operating_window?(t)
        true
      end
      
      def can_login_again?(t)
        self.logout_time.nil? || ((t - self.logout_time) > 15)
      end

      def tick!
        send_heartbeat
      end

      def default_headers
        {
          'SenderCompID' => options[:sender_id],
          'TargetCompID' => options[:target_id],
          'MsgSeqNum'    => @msg_seq_num
        }.merge(options[:headers] || {})
      end

      def send_message(socket, message, resend = false)
        _info("Wrote: #{message.gsub("\01", ", ")}")
        socket.write(message)

        if !resend
          response = Response.new(message, schema: @schema)
          persistence.persist_sent(response)
          @msg_seq_num += 1
        end
        heartbeat_timer.try(:reset)
      end

      def full_read_partial(socket)
        socket.to_io.read_nonblock(BUFFER_SIZE)
      rescue Errno::EAGAIN
        nil
      end

      def read_message(socket)
        data = ""
        while buff = full_read_partial(socket)
          data << buff
        end
        handle_read_message(data)
      rescue IOError, Errno::EBADF, Errno::ECONNRESET => ex
        _info "Connection Closed"
        # wait for 20 seconds.  ICE has a 15 second throttle limit for logon requests
        sleep 20
        raise FixSocketClosedError, "socket was closed on us" if @listening
      rescue Errno::ETIMEDOUT
        #no biggie, keep listening
      end

      def handle_read_message(data)
        responses = ResponseExtractor.new(@schema, data).responses
        responses.each do |response|
          handle_read_response(response)
        end
      end

      def handle_read_response(response)
        persistence.persist_rcvd(response) unless ["SecurityDefinition", "TradeCaptureReport"].include? response.message_name
        async.message_processor(response)
      end

      def message_processor(response)
        self.last_remote_heartbeat = Time.now
        message_name = response.message_name
        _info "Received #{message_name} message at #{Time.now}"

        case message_name
        when "TestRequest"
          async.send_heartbeat(response.test_req_i_d)
        when "Logon"
          #successful logon - request any missing messages
          handle_logon
        when "Logout"
          handle_logout
        when "SequenceReset"
          async.sequence_reset(response)
        when "ResendRequest"
          async.resend_requests(response)
        else
          if listeners.has_key?(message_name)
            begin
              processor_class = listeners[message_name]
              _info "Found processor #{processor_class.to_s} for message of type #{message_name}"
              processor = processor_class.new
              raise NotImplementedError, "Listener #{processor_class.to_s} (for message name #{message_name}) must implement #handle_message" unless processor.respond_to?(:handle_message)
              _info "Handling message... #{Time.now}"
              processor.handle_message(response, options)
              _info "Handling message complete. #{Time.now}"
            rescue StandardError => e
              _info e
              _info e.backtrace
            end
          else
            _info "No processor found for message of type #{message_name}"
          end
        end
      rescue UnknownMessageTypeError
        _info "Received unknown message #{response.message_hash}"
      end

      def handle_logon
        self.logged_out = false
        self.logout_time = nil
        async.request_missing_messages
      end

      def handle_logout
        self.logged_out = true
        self.logout_time = Time.now.utc.in_time_zone("Eastern Time (US & Canada)")
        self.terminate
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

      def strict?
        @strict
      end

      def listening?
        @listening
      end

      def send_test_request
        _send_message('TestRequest', { "TestReqID" => Time.now })
      end

      def send_logon_and_reset
        @msg_seq_num = 1
        # wipe out messages for account (they will still be in fix_message_history collection)
        persistence.clear_fix_messages

        params = {
          'EncryptMethod' => "0",
          'HeartBtInt' => config.heartbeat_int.to_s,
          'RawData' => options[:password],
          'ResetSeqNumFlag' => true
        }
        _send_message("Logon", params)
      end

      def send_logon
        params = {
          'EncryptMethod' => "0",
          'HeartBtInt' => config.heartbeat_int.to_s,
          'RawData' => options[:password],
          'ResetSeqNumFlag' => !config.persistent
        }
        _send_message("Logon", params)
      end

      def send_sdr
      end

      def send_logout
        _send_message("Logout", { 'ForceLogout' => '0' })
      end

      def request_missing_messages
        persistence.missing_message_ranges.each do |start, finish|
          params = {
            "BeginSeqNo" => start,
            "EndSeqNo" => finish
          }
          _info "Requesting messages #{start} through #{finish}"
          _send_message("ResendRequest", params)
        end
      end

      def sequence_reset(request)
        persistence.reset_sequence(request)
      end

      def resend_requests(request)
        messages_to_resend = persistence.messages_to_resend(request.begin_seq_no, request.end_seq_no)
        messages = MessageResendProcessor.new(messages_to_resend, default_headers, schema, { strict: strict? }).reduced_messages
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
        _send_message("Heartbeat", params)
        check_if_remote_alive
      end

      def graceful_shutdown!
        send_logout if @socket
      rescue Errno::EPIPE
        shut_down
      end

      def pause_listener
        _info "Pausing listener..."
        @listening = false
        @socket.try(:close)
        ActiveRecord::Base.clear_all_connections!
      end

      def resume_listener
        _info "Resuming listener..."
        @socket = TCPSocket.new(self.options[:server_ip], self.options[:port])
        @listening = true
        ActiveRecord::Base.establish_connection
        async.run
      end

      def shut_down
        _info "Shutting down..."
      ensure
        @listening = false
        @heartbeat_timer.try(:cancel)
        @socket.try(:close)
        ActiveRecord::Base.clear_all_connections!
      end

      def _send_message(msg_type, msg_params)
        message_str = Message.new(@schema, msg_type, default_headers, msg_params, { strict: strict? }).full_message
        _info "Sending #{msg_type}:"
        send_message(@socket, message_str)
      end

      private

      def _info(message)
        Damage.configuration.logger.debug message
      end
    end
  end
end
