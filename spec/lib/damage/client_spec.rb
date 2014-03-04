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
