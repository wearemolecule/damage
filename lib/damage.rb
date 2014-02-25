require "damage/version"
require 'nokogiri'
require 'celluloid/io'
require 'active_support'
require "damage/schema"
require "damage/message_listener"
require "damage/message"
require "damage/response_extractor"
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
  class FixSocketClosedError < StandardError; end
  class MessageParseError < StandardError; end

  class Configuration
    attr_accessor :heartbeat_int, :persistent, :persistence_options, :persistence_class

    def initialize
      self.heartbeat_int = 30
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
