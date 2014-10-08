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
          end
        else
          Damage.configuration.logger.info "logged out in tick"
          if in_operating_window?(t)
            Damage.configuration.logger.info "Starting ICE FIX Listener after maintenance window"
            resume_listener
            send_logon_and_reset
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
         t.to_i <= ActiveSupport::TimeZone.new('Eastern Time (US & Canada)').local(t.year, t.month, t.day, 19, 32, 0).to_i)
      end

      def _within_weekday_operating_range?(t)
        return false unless t.weekday?
        !in_weekday_maintenance_window?(t) && !(t.friday? && t.to_i > ActiveSupport::TimeZone.new('Eastern Time (US & Canada)').local(t.year, t.month, t.day, 18, 28, 0).to_i)
      end

      def _within_weekend_operating_range?(t)
        t.sunday? && t > ActiveSupport::TimeZone.new('Eastern Time (US & Canada)').local(t.year, t.month, t.day, 17, 0, 0)
      end

      def handle_logout
        self.logged_out = true
        pause_listener
      end

      def logged_out?
        @logged_out
      end

      def send_logout
        @listening = false
        _send_message("Logout",{})
        sleep(1)
      end

      def logged_in?
        !logged_out?
      end

      def last_transaction_time
        # ICE only stores current + previous day's history
        yesterday = Time.now.utc.yesterday.beginning_of_day
        # Get the last TradeCaptureReportReceived (msg_type == 'AE')
        last_message = FixMessage.desc(:created_at).where(msg_type: 'AE').limit(1).first.try(:created_at) || yesterday
        history_last_message = FixMessageHistory.desc(:created_at).where(msg_type: 'AE').limit(1).first.try(:created_at) || yesterday
        last_update = [last_message, history_last_message, yesterday].max
        last_update
      end
    end
  end
end
