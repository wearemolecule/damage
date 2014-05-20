require 'spec_helper'

describe Damage::Client::Base do
  let(:mixin) { self.described_class }
  let(:klass) { Class.new(Object) do; end }
  let(:instance) { klass.new([], options) }

  before { klass.send(:include, mixin) }
  
  let(:host) { '127.0.0.1' }
  let(:port) { 16990 }
  let(:schema_name) { "TTFIX42" }
  let(:schema) { Damage::Schema.new("schemas/#{schema_name}.xml") }
  let(:base_options) { {server_ip: host, port: port, schema_name: schema_name} }
  let(:options) { base_options }
  let(:server) { Damage::FakeFixServer.new(host, port, schema) }

  subject { instance }

  around do |ex|
    Celluloid.boot
    ex.run
    Celluloid.shutdown
  end

  before do
    Celluloid.logger = nil
    server

    instance
  end

  after do
    server.terminate
  end

  describe '#default_headers' do
    subject { instance.default_headers }
    let(:id_options) { { sender_id: sender_id, target_id: target_id } }
    let(:sender_id) { 1234 }
    let(:target_id) { 4567 }
    
    it { should be_a Hash }
    it { should include 'SenderCompID' }
    it { should include 'TargetCompID' }
    it { should include 'MsgSeqNum' => server.received_messages.count + 1 }

    context 'include the sender and target ids' do
      let(:options) { id_options.merge(base_options) }
      it { should include 'SenderCompID' => sender_id }
      it { should include 'TargetCompID' => target_id }
    end

    context 'when supplied with additional headers, includes them' do
      let(:schema_name) { "FIX44" }
      let(:options) { id_options.merge(additional_headers).merge(base_options) }
      let(:additional_headers) do
        {
          headers: {
            'SenderSubID' => 123,
            'Username' => 'foo',
            'Password' => 'bar'
          }
        }
      end
      it { should include 'SenderSubID' }
      it { should include 'Username' }
      it { should include 'Password' }
    end
  end

  describe '#new' do
    it "should send logon message" do
      server.received_messages.count.should eq 1
      server.received_messages.first.should match(/35=A/)
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

  describe '#send_heartbeat' do

    subject { instance.send_heartbeat }
  end

  describe '#time_since_test_request' do
    let(:test_request_sent) { Time.now }

    subject { instance.time_since_test_request }

    before do
      instance.instance_variable_set :@test_request_sent, test_request_sent
    end

    it { should eq 0 }

    context '60 seconds ago' do
      let(:test_request_sent) { Time.now - 60.seconds }
      it { should eq 60 }
    end

    context 'nil' do
      let(:test_request_sent) { nil }
      it { should eq 0 }
    end
  end

  describe '#time_since_heartbeat' do
    let(:last_remote_heartbeat) { Time.now }

    subject { instance.time_since_heartbeat }

    before do
      instance.instance_variable_set :@last_remote_heartbeat, last_remote_heartbeat
    end

    it { should eq 0 }

    context '60 seconds ago' do
      let(:last_remote_heartbeat) { Time.now - 60.seconds }
      it { should eq 60 }
    end

    context 'nil' do
      let(:last_remote_heartbeat) { nil }
      it { should eq 0 }
    end
  end

  describe '#above_loss_tolerance' do
    let(:heartbeat_interval) { 30 }

    subject { instance.above_loss_tolerance(time_since) }

    before do
      instance.heartbeat_interval = heartbeat_interval
    end

    context "less than tolerance" do
      let(:time_since) { 30 }

      it { should be_false }
    end

    context "greater than tolerance" do
      let(:time_since) { 60 }

      it { should be_true }
    end
  end

  describe '#check_if_remote_alive' do
    let(:test_request_sent) { nil }
    let(:last_remote_heartbeat) { Time.now }
    before do
      instance.heartbeat_interval = 30
      instance.instance_variable_set :@test_request_sent, test_request_sent
      instance.instance_variable_set :@last_remote_heartbeat, last_remote_heartbeat
    end

    subject { instance.check_if_remote_alive }

    it { should be_false }

    context 'with expired heartbeat' do
      let(:last_remote_heartbeat) { Time.now - 60.seconds }

      it { should be_true }
    end
  end
end
