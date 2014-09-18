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
            send_logon
          end
        end
      end

      TIME_FORMAT = "%H:%M:%S"
      # Times in EST with a +- minute on either side.  using in_time_zone will take daylight savings time out of play
      ICE_WEEKDAY_MAINT_WINDOW_START = "18:28:00"
      ICE_WEEKDAY_MAINT_WINDOW_END = "19:32:00"
      WEEKDAY_MAINTENANCE_WINDOW = (ICE_WEEKDAY_MAINT_WINDOW_START..ICE_WEEKDAY_MAINT_WINDOW_END).to_a.freeze

      def in_operating_window?(t)
        _within_weekday_operating_range?(t) || _within_weekend_operating_range?(t)
      end

      def in_maintenance_window?(t)
        !in_operating_window?(t)
      end

      def _within_time_range?(t, time_range)
        time_range.include?(t.strftime(TIME_FORMAT))
      end

      def _within_weekday_operating_range?(t)
        return false unless t.weekday?

        if t.friday?
          t < Time.parse("#{t.to_date.strftime("%Y-%m-%d")} #{ICE_WEEKDAY_MAINT_WINDOW_START}")
        else
          !_within_time_range?(t, WEEKDAY_MAINTENANCE_WINDOW)
        end
      end

      def _within_weekend_operating_range?(t)
        t.sunday? && t > Time.utc(t.year, t.month, t.day, 21, 0, 0).in_time_zone("Eastern Time (US & Canada)")
      end

      def logged_out?
        @logged_out
      end

      def logged_in?
        !logged_out?
      end

      def last_transaction_time
        Date.today.to_time
      end

      # def _last_transaction_time
      #   last_missing_range_seqs = persistence.missing_message_ranges.flatten
      #   if last_missing_range_seqs
      #     last_received_seq_num = last_missing_range_seqs.first - 1
      #     last_received_msg = rcvd_messages.select do |m|
      #       m.msg_seq
      #     end
      #   else
      #     Time.now - 2.days
      #   end
      # end
    end
  end
end
