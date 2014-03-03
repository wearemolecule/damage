class Damage::FakeFixServer
  include Celluloid::IO
  include Celluloid::Logger
  finalizer :shut_down

  attr_accessor :schema, :received_messages

  def initialize(host, port, schema)
    @server = TCPServer.new(host, port)
    @schema = schema
    @sockets = []
    @received_messages = []

    async.run
  end

  def broadcast_message(message)
    @sockets.each do |socket|
      socket.write message
    end
  end

  def run
    loop {
      socket = @server.accept
      @sockets << socket
      async.handle_connection socket
    }
  end

  def handle_connection(socket)
    loop {
      data = socket.readpartial(4096)
      handle_incoming(socket, data)
    }
  end

  def handle_incoming(socket, data)
    # response = Damage::Response.new(schema, data)
    @received_messages << data
  end

  def shut_down
    @server.close if @server
  end
end
