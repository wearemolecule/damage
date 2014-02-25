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
    subject { instance.message_hash }

    it { should include({"BeginString" => "FIX.4.2"}) }
    it { should include({"BodySize" => 64}) }
    it { should include({"MsgType" => "0"}) }
    it { should include({"SenderID" => "TTDS68BO"}) }
    it { should include({"TargetID" => "MOLECULEDTS"}) }
    it { should include({"MsgSeqNum" => 768}) }
    it { should include({"SendingTime" => message_time}) }
    it { should include({"Checksum" => "085"}) }
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
