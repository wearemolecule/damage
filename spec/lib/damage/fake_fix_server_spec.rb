require 'spec_helper'

describe Damage::FakeFixServer do
  let(:klass)               { self.described_class }
  let(:server)              { klass.new(host, port, schema) }
  let(:host)                { '127.0.0.1' }
  let(:port)                { 16991 }
  let(:schema)              { Damage::Schema.new("schemas/#{schema_name}.xml") }
  let(:client)              { Damage::Client.new(vendor, [], client_options) }
  let(:client_options)      { base_client_options }
  let(:base_client_options) { { server_ip: host, port: port, schema_name: schema_name } }
  let(:base_headers) do
    {
      'SenderCompID' => 'ABCD',
      'TargetCompID' => 'EFGH',
      'MsgSeqNum' => 2
    }
  end
  
  around do |ex|
    Celluloid.boot
    ex.run
    Celluloid.shutdown
  end

  shared_examples_for "a standard FIX gateway" do
    before do
      Celluloid.logger = nil
      server.should_not be_nil
    end

    after do
      server.shut_down
    end

    subject { nil }

    describe "handles incoming" do
      it "Logon message" do
        expect do
          client
        end.to change{ server.received_messages.count }.from(0).to(1)
      end

      it "Logout message" do
        expect do
          client.send_logout
        end.to change{ server.received_messages.count }.from(0).to(2)
      end

      it "Test Request message" do
        expect do
          client.send_test_request
        end.to change{ server.received_messages.count }.from(0).to(2)
      end

      it "Heartbeat message" do
        expect do
          client.send_heartbeat
        end.to change{ server.received_messages.count }.from(0).to(2)
      end
    end

    describe "sends outgoing" do
      before do
        expect{ client }.to change{ server.received_messages.count }.from(0).to(1)
      end

      specify{ test_request.should be_valid }

      it "TestRequest message" do
        server.broadcast_message(test_request.full_message)
      end
    end
  end

  shared_examples_for "a FIX 4.2 gateway" do
    let(:headers) { base_headers }
    let(:test_request) { Damage::Message.new(schema, "TestRequest", headers, 'TestReqID' => 1) }
    it_should_behave_like "a standard FIX gateway"
  end

  describe "using a FIX 4.2 schema" do
    let(:vendor) { :trading_tech }
    # NOTE: the use of { strict: false } here (and in the FIX 4.4 examples, below
    #       are due to the existing convention in the library, which is biased towards
    #       the TT schema.  I want to minimize disruption at this stage of the game.
    #       However, one would think that a refactoring is in order and that a single
    #       vendor's non-standard schema definition should NOT be the default.
    #       -- @adamstrickland, 20140513
    let(:client_options) { base_client_options.merge(strict: false) }
    let(:schema_name) { "FIX42" }
    it_should_behave_like "a FIX 4.2 gateway"
  end

  describe "using a TT-customized FIX 4.2 schema" do
    let(:vendor) { :trading_tech }
    let(:schema_name) { "TTFIX42" }
    it_should_behave_like "a FIX 4.2 gateway"
  end

  describe "using a FIX 4.4 schema" do
    let(:vendor) { :ice }
    let(:client_options) { base_client_options.merge(strict: false) }
    let(:headers) { base_headers }
    let(:test_request) { Damage::Message.new(schema, "TestRequest", headers, 'TestReqID' => 1) }
    let(:schema_name) { "FIX44" }
    it_should_behave_like "a standard FIX gateway"
  end
end
