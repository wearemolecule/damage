module Damage
  module Vendor
    module IceClient
      def request_missing_messages
        final_missing = persistence.missing_message_ranges.last
        last_transaction = final_missing.try(:transact_time) if final_missing
        last_transaction ||= (Time.now - 2.days)
        last_transact_time = last_transaction
        last_trade_date = last_transaction.to_date
        params = {
          'TradeRequestID' => SecureRandom.hex.to_s,
          'TradeRequestType' => '0',
          'SubscriptionRequestType' => '1',
          'NoDates' => '1',
          'TradeDate' => last_trade_date,
          'TransactTime' => last_transact_time
        }
        message_str = Message.new(schema, "TradeCaptureReportRequest", default_headers, params, { strict: strict? }).full_message
        _info "Requesting trade capture with snapshot and subscription"
        send_message(socket, message_str)
      end
    end
  end
end
