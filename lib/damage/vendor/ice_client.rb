module Damage
  module Vendor
    module WeekdaySupportForTime
      def weekday?
        (1..5).include?(wday)
      end
    end

    ::Time.send(:include, WeekdaySupportForTime)

    module IceClient
      def request_missing_messages
        last_transact_time = last_transaction_time
        last_trade_date = last_transact_time.to_date
        params = {
          'TradeRequestID' => SecureRandom.hex.to_s,
          'TradeRequestType' => '0',
          'SubscriptionRequestType' => '1',
          'NoDates' => '1',
          'TradeDate' => last_trade_date,
          'TransactTime' => last_transact_time
        }
        message_str = Message.new(schema, "TradeCaptureReportRequest", default_headers, params, { strict: strict? }).full_message
        Damage.configuration.logger.info "Requesting trade capture with snapshot and subscription"
        send_message(socket, message_str)
      end

      def send_sdr(market_type)
        return if !logged_in?

        cfi_codes = %w(FXXXXX OXXXXX)
        params = {
          'SecurityReqID' => nil,
          'SecurityRequestType' => "3",
          'SecurityID' => nil,
          'CFICode' => nil
        }
        params['SecurityID'] = market_type
        cfi_codes.each do |cfi_code|
          params['SecurityReqID'] = SecureRandom.hex.to_s
          params['CFICode'] = cfi_code
          _send_message("SecurityDefinitionRequest", params)
        end
      end

      def tick!
        t = Time.now.utc.in_time_zone("Eastern Time (US & Canada)")
        if shutdown_time?(t) && @listening
          Damage.configuration.logger.info "Stopping ICE FIX Listener since it's #{t.strftime('%H:%M:%S')}"
          if logged_in?
            send_logout
          else
            pause_listener
          end
        end

        if logged_in?
          if in_maintenance_window?(t)
            Damage.configuration.logger.info "Stopping ICE FIX Listener for maintenance window"
            send_logout
          elsif in_operating_window?(t)
            send_heartbeat
            sdr_key = "ice:sdr:#{options[:account].id.to_s}"
            market_type = Resque.redis.get(sdr_key)
            if !market_type.blank? && market_type != "no"
              Damage.configuration.logger.info "Sending Security Definition Request. Account: #{options[:account].id.to_s}, market type: #{market_type}"
              Resque.redis.set(sdr_key, "no")
              send_sdr(market_type)
            end
          end
        else
          Damage.configuration.logger.info "logged out in tick"
          if in_operating_window?(t)
            Damage.configuration.logger.info "Starting ICE FIX Listener after maintenance window"
            resume_listener
          end
        end
      end

      # Times in EST with a +- minute on either side.  using in_time_zone will take daylight savings time out of play

      def shutdown_time?(t)
        t.to_i >= ActiveSupport::TimeZone.new('Eastern Time (US & Canada)').local(t.year, t.month, t.day, 21, 00, 0).to_i
      end

      def in_operating_window?(t)
        (_within_weekday_operating_range?(t) || _within_weekend_operating_range?(t)) && !shutdown_time?(t)
      end

      def in_maintenance_window?(t)
        !in_operating_window?(t)
      end

      def in_weekday_maintenance_window?(t)
        (t.to_i >= ActiveSupport::TimeZone.new('Eastern Time (US & Canada)').local(t.year, t.month, t.day, 18, 28, 0).to_i &&
         t.to_i <= ActiveSupport::TimeZone.new('Eastern Time (US & Canada)').local(t.year, t.month, t.day, 21, 0, 0).to_i)
      end

      def _within_weekday_operating_range?(t)
        return false unless t.weekday?
        !in_weekday_maintenance_window?(t) && !(t.friday? && t.to_i > ActiveSupport::TimeZone.new('Eastern Time (US & Canada)').local(t.year, t.month, t.day, 18, 28, 0).to_i)
      end

      def _within_weekend_operating_range?(t)
        t.sunday? && t > ActiveSupport::TimeZone.new('Eastern Time (US & Canada)').local(t.year, t.month, t.day, 17, 0, 0)
      end

      def handle_logon
        self.logged_out = false
        self.logout_time = nil
        if options['security_definition']
          Damage.configuration.logger.info "Starting Security Definition Request..."
          send_sdr
        end
        async.request_missing_messages
      end


      def handle_logout
        self.logged_out = true
        self.logout_time = Time.now.utc.in_time_zone("Eastern Time (US & Canada)")
        pause_listener
      end

      def logged_out?
        @logged_out
      end

      def send_logout
        @listening = false
        _send_message("Logout",{})
        handle_logout
      end

      def logged_in?
        !logged_out?
      end

      def last_transaction_time
        persistence.last_report_received
      end
    end
  end
end
