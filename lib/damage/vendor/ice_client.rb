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
        t = Time.now.utc

        if logged_in?
          if in_or_near_maintenance_window?(t)
            Damage.configuration.logger.info "Stopping ICE FIX Listener for maintenance window"
            send_logout
          elsif in_operating_window?(t)
            send_heartbeat
          end
        else
          if in_operating_window?(t)
            Damage.configuration.logger.info "Starting ICE FIX Listener after maintenance window"
            send_logon
          end
        end
      end

      TIME_FORMAT = "%H:%M:%S"
      ICE_WEEKDAY_MAINT_WINDOW_START = "22:30:00"
      ICE_WEEKDAY_MAINT_WINDOW_END = "23:30:00"
      WEEKDAY_MAINTENANCE_WINDOW = (ICE_WEEKDAY_MAINT_WINDOW_START..ICE_WEEKDAY_MAINT_WINDOW_END).to_a.freeze

      def in_operating_window?(t)
        _within_weekday_operating_range?(t) || _within_weekend_operating_range?(t)
      end

      def in_maintenance_window?(t)
        !in_operating_window?(t)
      end

      def in_or_near_maintenance_window?(t)
        near_maintenance_window?(t) || in_maintenance_window?(t)
      end

      def near_maintenance_window?(t)
        return false unless t.weekday?

        maint_window_threshold = (Time.parse(ICE_WEEKDAY_MAINT_WINDOW_START) - heartbeat_interval.seconds).strftime(TIME_FORMAT)
        maint_window_threshold_window = (maint_window_threshold..ICE_WEEKDAY_MAINT_WINDOW_START)

        _within_time_range?(t, maint_window_threshold_window)
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
        t.sunday? && t.hour > 21
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
