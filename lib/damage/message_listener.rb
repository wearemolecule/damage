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
      include Celluloid
      include Celluloid::Logger
      extend ClassMethods
    end

    def process(*)
      raise NotImplementedError, "listener must implement process"
    end
  end
end
