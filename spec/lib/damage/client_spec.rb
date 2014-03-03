require 'spec_helper'

describe Damage::Client do
  let(:klass) { self.described_class }
  let(:host) { '127.0.0.1' }
  let(:port) { 16990 }
  let(:schema_name) { "TTFIX42" }
  let(:schema) { Damage::Schema.new("schemas/TTFIX42.xml") }
  let(:options) { {server_ip: host, port: port, schema: schema_name} }
  let(:server) { Damage::FakeFixServer.new(host, port, schema) }
  let(:instance) { klass.new([], options) }

  subject { instance }

  before do
    Celluloid.logger = nil
    server

    instance
  end

  after do
    server.terminate
  end


  describe '#new' do
    it "should send logon message" do
      server.received_messages.count.should eq 1
      server.received_messages.first.should match /35=A/
    end
  end

  describe '#send_message' do
    before do
      instance.send_message(instance.socket, "Test")
    end

    it "should send any arbitrary message" do
      server.received_messages.count.should eq 2
      server.received_messages.last.should eq  "Test"
    end
  end
end
