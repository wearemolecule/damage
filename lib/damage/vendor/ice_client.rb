module Damage
  module Vendor
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
