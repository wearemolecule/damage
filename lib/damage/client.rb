module Damage
  class Client
    include Damage::Client::Base

    attr_accessor :vendor

    def initialize(vendor, listeners, options={})
      @vendor = vendor
      customization = "::Damage::Vendor::#{vendor.to_s.camelize}Client"
      begin
        self.send(:extend, customization.constantize)
      rescue NameError
        Damage.configuration.logger.warn "Unknown vendor '#{vendor}'.  Please implement #{customization}"
      end

      super(listeners, options)
    end
  end
end
