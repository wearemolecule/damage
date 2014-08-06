require 'spec_helper'

describe Damage::Response do
  let(:klass) { self.described_class }
  let(:instance) { klass.new(message) }
  # let(:base_message) { "8=FIX.4.2\u00019=00064\u000135=0\u000149=TTDS68BO\u000156=MOLECULEDTS\u000134=768\u000152=20140218-00:19:45.207\u000110=085\u0001" }
  let(:heartbeat) { "8=FIX.4.2\u00019=00064\u000135=0\u000149=TTDS68BO\u000156=MOLECULEDTS\u000134=768\u000152=20140218-00:19:45.207\u000110=085\u0001" }
  let(:message) { heartbeat }
  let(:message_time) { ActiveSupport::TimeWithZone.new(nil, ActiveSupport::TimeZone["UTC"], Time.utc(2014, 2, 18, 0, 19, 45, 207000)) }

  describe '#method_missing and #respond_to?' do
    subject { nil }

    context 'when the field is defined in the schema for the message' do
      let(:message) { "8=FIX.4.2\u00019=00064\u000135=A\u000149=TTDS68BO\u000156=MOLECULEDTS\u000134=768\u000152=20140218-00:19:45.207#{ field }\u000110=085\u0001" }

      context 'when the field is in the message' do
        let(:field) { "\u000198=1" }

        it { expect(instance.method_missing(:encrypt_method)).not_to be_nil }
        it { expect(instance.method_missing(:msg_type)).to eq "A" }

        it { expect(instance).to respond_to :msg_type }
        it { expect(instance).to respond_to :raw_data }
      end

      context 'but the field is NOT in the message itself' do
        let(:field) { "" }

        it { expect(instance.method_missing(:encrypt_method)).to be_nil }
        it { expect(instance.method_missing(:msg_type)).to eq "A" }

        it { expect(instance).to respond_to :msg_type }
        it { expect(instance).to respond_to :raw_data }
      end
    end

    context 'when the field is not defined in the schema for the message' do
      let(:message) { heartbeat }

      it { expect{ instance.method_missing(:encrypt_method) }.to raise_error }
      it { expect(instance.method_missing(:msg_type)).to eq "0" }

      it { expect(instance).to respond_to :msg_type }
      it { expect(instance).not_to respond_to :raw_data }
    end
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
      let(:schema) { double("schema") }
      let(:type_to_msg) { {"0" => "Heartbeat"} }
      let(:num_to_name) { {"8" => "BeginString", "9" => "BodySize", "35" => "MsgType",
                           "52" => "SendingTime", "49" => "SenderID", "56" => "TargetID",
                           "34" => "MsgSeqNum", "10" => "Checksum"} }
      let(:num_to_type) { {"8" => "STRING", "9" => "INT", "35" => "STRING",
                           "52" => "UTCTIMESTAMP", "49" => "STRING", "56" => "STRING",
                           "34" => "INT", "10" => "CHECKSUM"} }
      let(:instance) { klass.new(message, schema: schema) }

      before do
        schema.stub(:msg_name) { |type| type_to_msg[type] }
        schema.stub(:field_name) { |name| num_to_name[name] }
        schema.stub(:field_type) { |num| num_to_type[num] }
        schema.stub(:begin_string).and_return "FIX.4.2"
      end

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
      let(:schema_path) { File.join(File.dirname(__FILE__), '../../../lib/damage/schemas/ICEFIX44.xml') }
      let(:schema) { Damage::Schema.new(schema_path, relative: false) }
      let(:message) do
        "8=FIX.4.4\u00019=527\u000135=AE\u000149=ICE\u000134=5\u000152=20140528-15:09:06.066\u000156=6746\u000157=AGTS\u0001571=338\u0001487=0\u0001856=0\u0001828=0\u0001150=F\u000117=414584964\u000139=2\u0001570=N\u000155=595630\u000148=HNG SMV0014!\u000122=8\u0001461=FXXXXX\u0001207=IFED\u0001916=20141001\u0001917=20141031\u000132=2500.0\u000131=4.5\u00019018=31\u00019022=31\u000175=20140528\u000160=20140528-15:09:06.066\u00019413=0\u0001552=1\u000154=2\u000137=65001292\u000111=414584964\u0001453=8\u0001448=e360power\u0001447=D\u0001452=11\u0001448=October Futures LLC\u0001447=D\u0001452=13\u0001448=6745\u0001447=D\u0001452=56\u0001448=6745\u0001447=D\u0001452=35\u0001448=8745\u0001447=D\u0001452=4\u0001448=M25501 C\u0001447=D\u0001452=51\u0001448=JP Morgan Securities LLC\u0001447=D\u0001452=60\u0001448=W\u0001447=D\u0001452=54\u000110=167"
      end
      let(:instance) { klass.new(message, schema: schema) }

      before { schema.begin_string.should match %r{FIX\.4\.4} }

      it { should include "MsgType" => "AE" }
      it { should include "NoPartyIDs" }
      it { should include 'PartyRole' }
      it { should include 'PartyID' }
      it { message_hash['PartyRole'].should have(message_hash['NoPartyIDs'].to_i).items }
      it { message_hash['PartyID'].should have(message_hash['NoPartyIDs'].to_i).items }
      it { message_hash['PartyRole'].should include 11 }
      it { message_hash['PartyID'].should include 'e360power' }
      it { message_hash['PartyRole'].should include 13 }
      it { message_hash['PartyID'].should include 'October Futures LLC' }

      # the party ID for a given role can be found by correlating the two arrays
      it { message_hash['PartyRole'].index{ |pr| pr == 13 }.should eq message_hash['PartyID'].index{ |pi| pi == 'October Futures LLC' } }
      it { message_hash['PartyRole'].index{ |pr| pr == 11 }.should eq message_hash['PartyID'].index{ |pi| pi == 'e360power' } }
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

    before { instance.stub(:message_hash).and_return(message_hash) }

    let(:base_message_hash) do
      {
        "BeginString" => "FIX.4.2",
        "BodySize" => 64,
        "MsgType" => "0",
        "SenderId" => "BLAH",
        "TargetId" => "MOLECULEDTS",
        "MsgSeqNum" => 768,
        "SendingTime" => message_time,
        "Checksum" => "085"
      }
    end

    shared_examples_for "a well-formed, underscored hash" do
      it { should include({"begin_string" => "FIX.4.2"}) }
      it { should include({"body_size" => 64}) }
      it { should include({"msg_type" => "0"}) }
      it { should include({"sender_id" => "BLAH"}) }
      it { should include({"target_id" => "MOLECULEDTS"}) }
      it { should include({"msg_seq_num" => 768}) }
      it { should include({"sending_time" => message_time}) }
      it { should include({"checksum" => "085"}) }
    end

    context 'with a simple message hash' do
      let(:message_hash) { base_message_hash }
      it_should_behave_like "a well-formed, underscored hash"
    end

    context 'with a message hash with array values' do
      let(:message_hash) { base_message_hash.merge("PartyIDs" => ["A", "B"]) }
      it_should_behave_like "a well-formed, underscored hash"
    end
  end
end
