#!/usr/bin/env ruby

require 'thor'
require 'damage/schema'
require 'damage/client'
require 'damage/fake_fix_server'
require 'celluloid'

class DamageDotThor < Thor
  namespace :damage

  desc "client", "start a fix client"
  method_option :host, type: :string, default: "127.0.0.1", aliases: '-h'
  method_option :port, type: :numeric, default: 16900, aliases: '-p'
  method_option :schema, type: :string, default: "schemas/FIX42.xml", aliases: '-S'
  method_option :sender_comp_id, type: :string, required: true, aliases: '-s'
  method_option :target_comp_id, type: :string, required: true, aliases: '-t'
  method_option :sender_sub_id, type: :string 
  method_option :username, type: :string, aliases: '-u'
  method_option :password, type: :string, aliases: '-P'
  def client
    schema = _find_and_load_schema(options[:schema])

    listeners = []
    optional_headers = {}
    optional_headers['SenderSubId'] = options[:sender_sub_id] if options[:sender_sub_id]
    optional_headers['Username'] = options[:username] if options[:username]
    optional_headers['Password'] = options[:password] if options[:password]
    client_options = {
      sender_id: options[:sender_comp_id],
      target_id: options[:target_comp_id],
      server_ip: options[:host],
      port: options[:port],
      schema: schema,
      headers: optional_headers
    }

    supervisor = ::Celluloid::SupervisionGroup.run!
    supervisor.add(Damage::Client, { as: "DamageDotThor-client", args: [ listeners, client_options ]})

    Signal.trap("USR1") do
      supervisor.actors.each(&:graceful_shutdown!)
      supervisor.terminate
    end

    loop do
      sleep 5 while supervisor.alive?
    end
  end

  desc "client", "start a fix client"
  method_option :host, type: :string, default: "127.0.0.1", aliases: '-h'
  method_option :port, type: :numeric, default: 16900, aliases: '-p'
  method_option :schema, type: :string, default: "schemas/FIX42.xml", aliases: '-S'
  def server
    schema = _find_and_load_schema(options[:schema])
    Damage::FakeFixServer.new(options[:host], options[:port], schema)
  end

  private

  def _find_and_load_schema(path_provided)
    Damage::Schema.new(_find_schema(path_provided), relative: false)
  end

  def _find_schema(path_provided)
    schema_search_dirs = [Dir.pwd, File.dirname(__FILE__), File.join(File.dirname(__FILE__), '../lib/damage'), Dir.home, '/']
    possible_schema_paths = schema_search_dirs.map do |dir|
      File.join(dir, path_provided)
    end
    path_to_schema = possible_schema_paths.find do |path|
      File.exists?(path)
    end
    raise "Could not find a schema at any of these locations: #{possible_schema_paths.join(',')}.  Please provide a path to a FIX schema" if path_to_schema.nil?
    path_to_schema
  end

  # method_option :reset_seq_num, type: :boolean, default: false, aliases: '-R'
  # method_option :delete_history, type: :boolean, default: false, aliases: '-D'
  # def listen(vendor)
  #   supervisor = self.create_supervisor(vendor, options)

  #   Signal.trap("USR1") do
  #     supervisor.actors.each do |client|
  #       client.graceful_shutdown!
  #     end
  #     supervisor.terminate
  #   end

  #   loop do
  #     sleep 5 while supervisor.alive?
  #   end
  # end
end

DamageDotThor.start(ARGV)
