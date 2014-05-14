require 'damage/client_base'

module Damage
  class Client
    include Celluloid::IO
    include Celluloid::Logger
    include Damage::ClientBase

    finalizer :shut_down

    attr_accessor :vendor

    def initialize(vendor, listeners, options={})
      @vendor = vendor
      customization = "::Damage::Vendor::#{vendor.to_s.camelize}Client"
      begin
        self.send(:extend, customization.constantize)
      rescue NameError
        raise "Unknown vendor '#{vendor}'.  Please implement #{customization}"
      end

      super(listeners, options)
    end
  end
end
