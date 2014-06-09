require 'spec_helper'

describe Damage::MessageResendProcessor do

  let(:klass) { self.described_class }
  let(:messages) { [] }
  let(:headers) { {
    'SenderCompID' => "sender",
    'TargetCompID' => "target",
    'MsgSeqNum'    => 20
  } }
  let(:schema) { double() }
  let(:instance) { klass.new(messages, headers, schema) }

  describe "#initialize" do
    subject { instance }
    its(:headers) { should_not include 'MsgSeqNum' => 20 }
  end

  describe "#message_type" do
    let(:params) { {"MsgType" => "0", "Test" => "Other"} }

    subject { instance.message_type(params) }

    before do
      schema.should_receive(:msg_name).with("0").and_return("Heartbeat")
    end

    it { should eq "Heartbeat" }
    it { subject; params.should_not include 'MsgType' => "0" }
  end

  describe "#send_reset_instead?" do
    subject { instance.send_reset_instead?(type) }

    context "Logon" do
      let(:type) { "Logon" }
      it { should be_truthy }
    end
    context "Logout" do
      let(:type) { "Logout" }
      it { should be_truthy }
    end
    context "Heartbeat" do
      let(:type) { "Heartbeat" }
      it { should be_truthy }
    end
    context "ResendRequest" do
      let(:type) { "ResendRequest" }
      it { should be_truthy }
    end
    context "ExecutionReport" do
      let(:type) { "ExecutionReport" }
      it { should be_falsey }
    end
  end

  describe "#new_messages" do
    let(:schema) { Damage::Schema.new("schemas/TTFIX42.xml") }
    let(:logon) { {"MsgType" => "A", "MsgSeqNum" => 1 } }
    let(:exec_rep) { {"MsgType" => "8", "MsgSeqNum" => 2 } }

    subject { instance.new_messages }

    context "single message as reset" do
      let(:messages) { [logon] }

      its(:count) { should eq 1 }

      it {
        message = subject.first
        message.properties.should include "MsgSeqNum" => 1
        message.properties.should include "NewSeqNo" => 2
        message.properties.should include "GapFillFlag" => true
        message.properties.should include "PossDupFlag" => true
        message.type.should eq "4"
      }
    end

    context "non reset message" do
      let(:messages) { [exec_rep] }

      its(:count) { should eq 1 }

      it {
        message = subject.first
        message.properties.should include "MsgSeqNum" => 2
        message.properties.should_not include "GapFillFlag" => true
        message.properties.should include "PossDupFlag" => true
        message.type.should eq "8"
      }
    end

    context "reset and non-reset" do
      let(:messages) { [logon, exec_rep] }

      its(:count) { should eq 2 }

      it { subject.first.type.should eq "4" }
      it { subject.last.type.should eq "8" }
    end
  end

  describe "#reduce_messages" do
    let(:schema) { Damage::Schema.new("schemas/TTFIX42.xml") }
    let(:seq_reset1) { Damage::Message.new(schema, "SequenceReset", headers, {"MsgSeqNum" => 1, "NewSeqNo" => 2}) }
    let(:seq_reset2) { Damage::Message.new(schema, "SequenceReset", headers, {"MsgSeqNum" => 2, "NewSeqNo" => 3}) }
    let(:non_seq_reset) { Damage::Message.new(schema, "SequenceReset", headers, {"MsgSeqNum" => 4, "NewSeqNo" => 5}) }
    let(:reg_message) { Damage::Message.new(schema, "ExecutionReport", headers, {}) }
    let(:messages) { [] }
    subject { instance.reduce_messages(messages) }

    it { should eq [] }

    context "single reset" do
      let(:messages) { [seq_reset1] }

      it { should eq [seq_reset1] }
    end

    context "two resets" do
      let(:messages) { [seq_reset1, seq_reset2] }

      it { should eq [seq_reset1] }
      it { subject.first.properties.should include "NewSeqNo" => 3 }
    end
    context "two non-sequential resets" do
      let(:messages) { [seq_reset1, non_seq_reset] }

      it { should eq [seq_reset1, non_seq_reset] }
      it { subject.first.properties.should include "NewSeqNo" => 2 }
    end
    context "reset and regular message" do
      let(:messages) { [seq_reset1, reg_message] }

      it { should eq [seq_reset1, reg_message] }
      it { subject.first.properties.should include "NewSeqNo" => 2 }
    end
    context "two resets and regular message" do
      let(:messages) { [seq_reset1, seq_reset2, reg_message] }

      it { should eq [seq_reset1, reg_message] }
      it { subject.first.properties.should include "NewSeqNo" => 3 }
    end
    context "two resets, non-sequential reset and regular message" do
      let(:messages) { [seq_reset1, seq_reset2, non_seq_reset, reg_message] }

      it { should eq [seq_reset1, non_seq_reset, reg_message] }
      it { subject.first.properties.should include "NewSeqNo" => 3 }
    end
  end

  describe "#reduced_messages" do
    let(:messages) { double }
    subject { instance.reduced_messages }

    before do
      instance.should_receive(:new_messages).and_return messages
      instance.should_receive(:reduce_messages).with(messages).and_return true
    end

    it { should be_truthy }
  end
end
