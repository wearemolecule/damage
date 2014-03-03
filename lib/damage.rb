require 'active_support/concern'
require 'active_support/time_with_zone'
require 'active_support/core_ext/time'
require 'bigdecimal'
require 'celluloid/io'
require 'nokogiri'

require "damage/client"
require "damage/message"
require "damage/message_listener"
require "damage/message_resend_processor"
require "damage/persistence/file_persistence"
require "damage/persistence/null_persistence"
require "damage/response"
require "damage/response_extractor"
require "damage/schema"
require "damage/version"

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
