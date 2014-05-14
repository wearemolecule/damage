#!/usr/bin/env ruby

require 'thor'
require 'damage'
require 'damage/fake_fix_server'
require 'celluloid'

class DamageDotThor < Thor
  namespace :damage

  DEFAULT_HOST = "127.0.0.1"
  DEFAULT_PORT = 16900
  DEFAULT_DB_URL = "mongodb://localhost/damage_dot_thor"
  DEFAULT_DATA_DIR = "."
  DEFAULT_DATA_FILE = "#{DEFAULT_DATA_DIR}/damage.dat"
  DEFAULT_SCHEMA = "schemas/FIX42.xml"

  desc "client", "start a fix client"
  method_option :host, type: :string, default: DEFAULT_HOST, aliases: '-h'
  method_option :port, type: :numeric, default: DEFAULT_PORT, aliases: '-p'
  method_option :schema, type: :string, default: DEFAULT_SCHEMA, aliases: '-S'
  # method_option :database, type: :string, default: DEFAULT_DB_URL, aliases: '-d'
  method_option :data_directory, type: :string, default: DEFAULT_DATA_DIR, aliases: '-d'
  method_option :reset, type: :boolean, default: false, aliases: '-r'
  method_option :sender_comp_id, type: :string, required: true, aliases: '-s'
  method_option :target_comp_id, type: :string, required: true, aliases: '-t'
  method_option :username, type: :string, aliases: '-u'
  method_option :password, type: :string, aliases: '-P'
  method_option :sender_sub_id, type: :string 
  def client
    schema = _find_and_load_schema(options[:schema])

    _configure(options[:data_directory], options[:reset])

    listeners = []
    optional_headers = {}
    optional_headers['SenderSubID'] = options[:sender_sub_id] if options[:sender_sub_id]
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

  desc "server", "start a fake fix server"
  method_option :host, type: :string, default: DEFAULT_HOST, aliases: '-h'
  method_option :port, type: :numeric, default: DEFAULT_PORT, aliases: '-p'
  method_option :schema, type: :string, default: DEFAULT_SCHEMA, aliases: '-S'
  method_option :data_directory, type: :string, default: DEFAULT_DATA_DIR, aliases: '-d'
  def server
    schema = _find_and_load_schema(options[:schema])
    # Damage::FakeFixServer.new(options[:host], options[:port], schema)

    _configure(options[:data_directory], options[:reset])

    supervisor = ::Celluloid::SupervisionGroup.run!
    supervisor.add(Damage::FakeFixServer, { as: "DamageDotThor-server", args: [ options[:host], options[:port], schema ] })

    Signal.trap("USR1") do
      supervisor.actors.each(&:graceful_shutdown!)
      supervisor.terminate
    end

    loop do
      sleep 5 while supervisor.alive?
    end
  end

  private

  def _configure(file_dir, reset=true)
    Damage.configure do |config|
      config.heartbeat_int = 30
      config.persistent = reset
      config.persistence_options = {
        sent_file_path: "#{file_dir}/sent.dat",
        rcvd_file_path: "#{file_dir}/rcvd.dat"
      }
      config.persistence_class = Damage::Persistence::FilePersistence
    end
  end

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
