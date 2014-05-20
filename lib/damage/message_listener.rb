module Damage
  module MessageListener
    extend ActiveSupport::Concern

    module ClassMethods
      def fix_message_name
        demodulized = self.name.demodulize
        demodulized.gsub("Listener", "")
      end
    end

    included do
      include Celluloid::Logger
      extend ClassMethods
    end

    # def handle_message(*)
    # end
  end
end
