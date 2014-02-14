module Damage
  module Persistence
    #WIP
    class FilePersistence
      attr_accessor :options, :read_file, :write_file

      def initialize(options)
        self.options = options
        raise StandardError, "must provide a sent history file" unless options.has_key? :sent_file_path
        raise StandardError, "must provide a received history file" unless options.has_key? :rcvd_file_path
        self.sent_file = file_from_path(options[:sent_file_path])
        self.rcvd_file = file_from_path(options[:rcvd_file_path])
      end

      def file_from_path(path)
        File.open(path, "a+")
      end

      def persist_sent(message)
        sent_file.write(message + "\n")
      end

      def persist_rcvd(message)
        rcvd_file.write(message + "\n")
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
