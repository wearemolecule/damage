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
end
