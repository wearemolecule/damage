require "damage/version"
require 'nokogiri'
require 'celluloid-io'

module Damage
  class Configuration
    attr_accessor :server_ip, :port, :sender_id, :target_id, :password, :heartbeat_int, :schema, :persistent

    def initialize
      self.server_ip = '127.0.0.1'
      self.port = 10690
      self.sender_id = "SENDER"
      self.target_id = "TARGET"
      self.password = ""
      self.heartbeat_int = 30
      self.schema = "TTFIX42"
      self.persistent = false
    end
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configure
    yield(configuration) if block_given?
  end
end
