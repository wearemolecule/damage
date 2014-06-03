#!/usr/bin/env ruby

require 'thor'
require 'damage'
require 'damage/fake_fix_server'
require 'celluloid'
require 'highline/import'

class DamageDotThor < Thor
  namespace :damage

  DEFAULT_HOST = "127.0.0.1"
  DEFAULT_PORT = 16900
  DEFAULT_DB_URL = "mongodb://localhost/damage_dot_thor"
  DEFAULT_DATA_DIR = "."
  DEFAULT_DATA_FILE = "#{DEFAULT_DATA_DIR}/damage.dat"
  DEFAULT_SCHEMA = "schemas/FIX42.xml"

  class_option :host, type: :string, default: DEFAULT_HOST, aliases: '-h'
  class_option :port, type: :numeric, default: DEFAULT_PORT, aliases: '-p'
  class_option :schema, type: :string, default: DEFAULT_SCHEMA, aliases: '-S'
  class_option :data_directory, type: :string, default: DEFAULT_DATA_DIR, aliases: '-d'

  desc "client", "start a fix client"
  method_option :vendor, type: :string, default: "nothing", aliases: '-v'
  method_option :sender_comp_id, type: :string, required: true, aliases: '-s'
  method_option :target_comp_id, type: :string, required: true, aliases: '-t'
  method_option :reset, type: :boolean, default: false, aliases: '-r'
  method_option :username, type: :string, aliases: '-u'
  method_option :password, type: :string, aliases: '-P'
  method_option :sender_sub_id, type: :string 
  def client
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
      headers: optional_headers
    }

    _start_fix_communication(options) do |supervisor, schema|
      supervisor.add(Damage::Client, { as: :client, args: [ options[:vendor], listeners, client_options.merge(schema: schema) ]})
    end

    _run_loop do
      _show_menu options[:schema]
    end
  end

  desc "server", "start a fake fix server"
  def server
    _run(options) do |supervisor, schema|
      supervisor.add(Damage::FakeFixServer, { as: :server, args: [ options[:host], options[:port], schema ] })
    end
  end

  private

  def _client
    _supervisor.actors.find{ |a| a.name == :client }
  end

  def _supervisor
    @supervisor
  end

  def _show_menu(schema)
    choose do |menu|
      menu.index = :letter
      menu.index_suffix = ') '
      # menu.layout = :menu_only
      # menu.shell = true
      # menu.prompt = color('What would you like to do?', :blue)
      menu.prompt = 'What would you like to do?'
      menu.choice(:send, "<%= color('Send a FIX message.', :blue) %>") do |command, details|
        msg_type = ask("MsgType")
        fields = []
        loop do
          field = ask("Field(s) [e.g. 'FieldName=FieldValue [NextFieldName=NextFieldValue]': ")
          break if field == ""
          fields << field
        end
        msg_fields = Hash[*fields.map{ |f| f.split(/[\s=]/) }.flatten]
        _client._send_message(msg_type, msg_fields)
      end
      menu.choice(:quit, "<%= color('Quit.', :blue) %>") do
        # Process.kill("USR1")
        exit
      end
    end
  end
  
  def _run_loop
    loop do
      yield if block_given?
      sleep 5 while @supervisor.alive?
    end
  end

  def _run(options, &block)
    _start_fix_communication(options, &block)
  end

  def _start_fix_communication(options, &block)
    schema = _find_and_load_schema(options[:schema])
    _configure(options[:data_directory], options[:reset])
    @supervisor = ::Celluloid::SupervisionGroup.run!

    block.call(@supervisor, schema)
    # supervisor.add(Damage::FakeFixServer, { as: "DamageDotThor-server", args: [ options[:host], options[:port], schema ] })

    Signal.trap("USR1") do
      @supervisor.actors.each(&:graceful_shutdown!)
      @supervisor.terminate
    end
  end

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
