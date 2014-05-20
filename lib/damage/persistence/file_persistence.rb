module Damage
  module Persistence
    class FilePersistence
      attr_accessor :options, :rcvd_file, :sent_file

      def initialize(options)
        self.options = options
        raise StandardError, "must provide a sent history file" unless options.has_key? :sent_file_path
        raise StandardError, "must provide a received history file" unless options.has_key? :rcvd_file_path
        self.sent_file = _file_from_path(options[:sent_file_path])
        self.rcvd_file = _file_from_path(options[:rcvd_file_path])
      end

      def persist_sent(message)
        _write_to(sent_file, message)
      end

      def persist_rcvd(message)
        _write_to(rcvd_file, message)
      end

      def missing_message_ranges
        []
      end

      def reset_sequence(request)

      end

      def messages_to_resend(start, finish)
        []
      end

      def current_rcvd_seq_num
        1
      end

      def current_sent_seq_num
        1
      end

      private

      def _file_from_path(path)
        File.open(path, "a+")
      end

      def _write_to(handle, response)
        message = response.message_hash
        handle.puts(message)
        handle.flush
      end
    end
  end
end
