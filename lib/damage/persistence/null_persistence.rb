module Damage
  module Persistence

    #Used when persistence is turned off
    class NullPersistence
      attr_accessor :options, :read_file, :write_file

      def initialize(*)
      end

      def file_from_path(*)
      end

      def reset_sequence(*)
      end

      def persist_sent(*)
      end

      def persist_rcvd(*)
      end

      def current_rcvd_seq_num
        1
      end

      def current_sent_seq_num
        1
      end
    end
  end
end
