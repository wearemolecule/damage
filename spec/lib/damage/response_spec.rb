require 'spec_helper'

describe Damage::Response do
  let(:klass) { self.described_class }
  let(:schema) { double("schema") }
  let(:type_to_msg) { {"0" => "Heartbeat"} }
  let(:num_to_name) { {"8" => "BeginString", "9" => "BodySize", "35" => "MsgType",
                       "52" => "SendingTime", "49" => "SenderID", "56" => "TargetID",
                       "34" => "MsgSeqNum", "10" => "Checksum"} }
  let(:num_to_type) { {"8" => "STRING", "9" => "INT", "35" => "STRING",
                       "52" => "UTCTIMESTAMP", "49" => "STRING", "56" => "STRING",
                       "34" => "INT", "10" => "CHECKSUM"} }
  let(:heartbeat) { "8=FIX.4.2\u00019=00064\u000135=0\u000149=TTDS68BO\u000156=MOLECULEDTS\u000134=768\u000152=20140218-00:19:45.207\u000110=085\u0001" }
  let(:message_time) { ActiveSupport::TimeWithZone.new(nil, ActiveSupport::TimeZone["UTC"], Time.utc(2014, 2, 18, 0, 19, 45, 207000)) }
  let(:message) { heartbeat }
  let(:instance) { klass.new(schema, message) }
  before do
    schema.stub(:msg_name) { |type| type_to_msg[type] }
    schema.stub(:field_name) { |name| num_to_name[name] }
    schema.stub(:field_type) { |num| num_to_type[num] }
    schema.stub(:begin_string).and_return "FIX.4.2"
  end

  describe '#cast_field_value' do
    subject { instance.cast_field_value(type, value) }
    let(:type) { "STRING" }
    let(:value) { "test" }

    it { should eq value }

    context "INT" do
      let(:type) { "INT" }
      let(:value) { "100" }

      it { should eq 100 }
    end

    context "PRICE" do
      let(:type) { "PRICE" }
      let(:value) { "123" }

      it { subject.to_f.should eq 1.23 }

      context "with decimals" do
        let(:value) { "123.42" }
        it { subject.to_f.should eq 1.2342 }
      end
    end

    context "UTCTIMESTAMP" do
      let(:type) { "UTCTIMESTAMP" }
      let(:value) { "20140218-00:19:45.207" }

      it { should eq message_time}
    end

    context "BOOLEAN" do
      let(:type) { "BOOLEAN" }

      context "true" do
        let(:value) { "Y" }

        it { should be_true }
      end

      context "false" do
        let(:value) { "F" }

        it { should be_false }
      end
    end
  end

  describe '#message_components' do
    subject { instance.message_components }

    it { should eq ["8=FIX.4.2", "9=00064", "35=0", "49=TTDS68BO", "56=MOLECULEDTS", "34=768", "52=20140218-00:19:45.207", "10=085"] }
  end

  describe '#message_hash' do
    let(:message_hash) { instance.message_hash }
    subject { message_hash }

    context 'when the FIX message is pretty simple, like a Heartbeat' do
      it { should include({"BeginString" => "FIX.4.2"}) }
      it { should include({"BodySize" => 64}) }
      it { should include({"MsgType" => "0"}) }
      it { should include({"SenderID" => "TTDS68BO"}) }
      it { should include({"TargetID" => "MOLECULEDTS"}) }
      it { should include({"MsgSeqNum" => 768}) }
      it { should include({"SendingTime" => message_time}) }
      it { should include({"Checksum" => "085"}) }
    end

    context 'when the FIX message contains repeated groups, like a TradeCaptureReport' do
      let(:schema_path) { 'schemas/FIX44.xml' }
      let(:schema) { Damage::Schema.new(schema_path) }
      let(:message) do
        "8=FIX.4.4\u00019=527\u000135=AE\u000149=ICE\u000134=5\u000152=20140528-15:09:06.066\u000156=6746\u000157=AGTS\u0001571=338\u0001487=0\u0001856=0\u0001828=0\u0001150=F\u000117=414584964\u000139=2\u0001570=N\u000155=595630\u000148=HNG SMV0014!\u000122=8\u0001461=FXXXXX\u0001207=IFED\u0001916=20141001\u0001917=20141031\u000132=2500.0\u000131=4.5\u00019018=31\u00019022=31\u000175=20140528\u000160=20140528-15:09:06.066\u00019413=0\u0001552=1\u000154=2\u000137=65001292\u000111=414584964\u0001453=8\u0001448=e360power\u0001447=D\u0001452=11\u0001448=October Futures LLC\u0001447=D\u0001452=13\u0001448=6745\u0001447=D\u0001452=56\u0001448=6745\u0001447=D\u0001452=35\u0001448=8745\u0001447=D\u0001452=4\u0001448=M25501 C\u0001447=D\u0001452=51\u0001448=JP Morgan Securities LLC\u0001447=D\u0001452=60\u0001448=W\u0001447=D\u0001452=54\u000110=167"
      end

      it { should include "MsgType" => "AE" }
      it { should include "NoPartyIDs" }

      context 'and the group is an Array of Hashes' do
        subject { message_hash['NoPartyIDs'] }
        # it { should have(8).items }
        # it { should include hash_including('PartyRole' => '11') }
        # it { should include hash_including('PartyID' => 'e360power') }
        # it { should include hash_including('PartyRole' => '13') }
        # it { should include hash_including('PartyID' => 'October Futures LLC') }
      end
    end
  end

  describe '#message_type' do
    subject { instance.message_type }

    it { should eq "Heartbeat" }
  end

  describe '#original_message' do
    subject { instance.original_message }

    it { should eq message }
  end

  describe '#underscored_keys' do
    subject { instance.underscored_keys }

    it { should include({"begin_string" => "FIX.4.2"}) }
    it { should include({"body_size" => 64}) }
    it { should include({"msg_type" => "0"}) }
    it { should include({"sender_id" => "TTDS68BO"}) }
    it { should include({"target_id" => "MOLECULEDTS"}) }
    it { should include({"msg_seq_num" => 768}) }
    it { should include({"sending_time" => message_time}) }
    it { should include({"checksum" => "085"}) }
  end
end
