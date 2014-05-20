require 'spec_helper'

describe Damage::Schema do
  let(:klass) { self.described_class }
  let(:schema) { "schemas/FIX42.xml" }

  let(:instance) { klass.new(schema) }

  describe '#begin_string' do
    subject { instance.begin_string }

    it { should eq "FIX.4.2" }
  end

  describe '#field_name' do
    let(:number) { "8" }
    subject { instance.field_name(number) }

    context "number as string" do
      it { should eq "BeginString" }
    end

    context "number as integer" do
      let(:number) { 8 }
      it { should eq "BeginString" }
    end

    context "unknown field" do
      let(:number) { "9999999" }
      it { should eq "Unknown9999999" }
    end
  end

  describe '#field_number' do
    let(:name) { "BeginString" }
    let(:strict) { true }

    let(:action!) { instance.field_number(name, strict) }
    subject { action! }

    context "name is known" do
      it { should eq "8" }
    end

    context "unknown name" do
      let(:name) { "Unknown542342" }
      it { should eq "542342" }
    end

    context "name can't be found" do
      let(:name) { "XXXKKLJIINNLLLKJHI" }
      context "and strict is enabled" do
        subject { nil }
        specify { expect{ action! }.to raise_error }
      end

      context "and strict is disabled" do
        let(:strict) { false }
        it { should eq nil }
      end

      context "and strict is nil" do
        let(:strict) { nil }
        it { should eq nil }
      end
    end
  end

  describe '#field_type' do
    let(:number) { "6" }
    subject { instance.field_type(number) }

    context "number as string" do
      it { should eq "PRICE" }
    end

    context "number as integer" do
      let(:number) { 6 }
      it { should eq "PRICE" }
    end

    context "unknown field" do
      let(:number) { "9999999" }
      it { should eq "STRING" }
    end
  end

  describe "#msg_name" do
    let(:msg_type) { "0" }
    subject { instance.msg_name(msg_type) }

    context "type as a string" do
      it { should eq "Heartbeat" }
    end

    context "type as a string" do
      let(:msg_type) { 0 }
      it { should eq "Heartbeat" }
    end

    context "unknown message type" do
      let(:msg_type) { "423" }
      it { expect{subject}.to raise_error(Damage::UnknownMessageTypeError) }
    end
  end

  describe "#msg_type" do
    let(:msg_name) { "Heartbeat" }
    subject { instance.msg_type(msg_name) }

    context "existing name" do
      it { should eq "0" }
    end

    context "invalid message type" do
      let(:msg_name) { "Bizarro" }
      it { expect{subject}.to raise_error(Damage::UnknownMessageTypeError) }
    end
  end

  describe '#header_fields' do
    subject { instance.header_fields }

    it { should be_an Nokogiri::XML::NodeSet }
    it { should have(27).items }
  end

  describe '#required_header_fields' do
    subject { instance.required_header_fields }

    it { should be_an Nokogiri::XML::NodeSet }
    it { should have(7).items }
  end

  describe '#header_field_names' do
    subject { instance.header_field_names }

    it { should be_an Array }
    it { should have(27).items }
    # it { should include 'MaxMessageSize' }
  end

  describe '#required_header_field_names' do
    subject { instance.required_header_field_names }

    it { should be_an Array }
    it { should have(7).items }
    it { should include 'BeginString' }
    it { should include 'BodyLength' }
    it { should include 'MsgType' }
    it { should include 'SenderCompID' }
    it { should include 'TargetCompID' }
    it { should include 'MsgSeqNum' }
    it { should include 'SendingTime' }
  end

  describe '#fields_for_message' do
    let(:msg_name) { 'Logon' }

    subject { instance.fields_for_message(msg_name) }

    it { should be_an Nokogiri::XML::NodeSet }
    it { should have(6).items }
  end

  describe '#required_fields_for_message' do
    let(:msg_name) { 'Logon' }

    subject { instance.required_fields_for_message(msg_name) }

    it { should be_an Nokogiri::XML::NodeSet }
    it { should have(2).items }
  end

  describe '#field_names_for_message' do
    let(:msg_name) { 'Logon' }

    subject { instance.field_names_for_message(msg_name) }

    it { should be_an Array }
    it { should have(6).items }
    it { should include 'EncryptMethod' }
    it { should include 'HeartBtInt' }
    it { should include 'RawDataLength' }
    it { should include 'RawData' }
    it { should include 'ResetSeqNumFlag' }
    it { should include 'MaxMessageSize' }
  end

  describe '#required_field_names_for_message' do
    let(:msg_name) { 'Logon' }

    subject { instance.required_field_names_for_message(msg_name) }

    it { should be_an Array }
    it { should have(2).items }
    it { should include 'EncryptMethod' }
    it { should include 'HeartBtInt' }
  end
end
