require "damage/version"
require 'nokogiri'
require 'celluloid/io'
require 'active_support'
require "damage/schema"
require "damage/message_type"
require "damage/message_listener"
require "damage/message"
require "damage/response"
require "damage/persistence/null_persistence"
require "damage/persistence/file_persistence"
require "damage/client"

module Damage
  #ASCII Start Of Header
  #Used to delimit traditional FIX messages
  SOH = "\01"

  class UnknownMessageTypeError < StandardError; end
  class UnknownFieldNameError < StandardError; end

  class Configuration
    attr_accessor :server_ip, :port, :sender_id, :target_id, :password, :heartbeat_int, :schema, :persistent, :persistence_options, :persistence_class

    def initialize
      self.server_ip = '127.0.0.1'
      self.port = 10690
      self.sender_id = "SENDER"
      self.target_id = "TARGET"
      self.password = ""
      self.heartbeat_int = 30
      self.schema = "TTFIX42"

      #Does not keep track of message sequence (resets count each time)
      self.persistent = false
      self.persistence_options = {}
      self.persistence_class = Damage::Persistence::NullPersistence
    end
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configure
    yield(configuration) if block_given?
  end
end
