require 'spec_helper'

describe Damage::Message do
  let(:klass) { self.described_class }
  let(:schema) { double("schema") }
  let(:msg_to_type) { {message_type => "0"} }
  let(:name_to_num) { {"SendingTime" => "10", "BooleanField" => "11", "StringField" => "12", "UtcField" => "13"} }
  let(:num_to_type) { {"10" => "UTCTIMESTAMP", "11" => "BOOLEAN", "12" => "STRING", "13" => "UTCTIMESTAMP"} }
  let(:headers) { {} }
  let(:properties) { {} }
  let(:current_time) { Time.utc(2013,1,1,0,0,0) }
  let(:message_type) { 'Heartbeat' }
  let(:instance) { klass.new(schema, message_type, headers, properties) }

  before do
    schema.stub(:msg_type) { |type| msg_to_type[type] }
    schema.stub(:field_number) { |name| name_to_num[name] }
    schema.stub(:field_type) { |num| num_to_type[num] }
    schema.stub(:begin_string).and_return "FIX.4.2"

    Timecop.freeze(current_time)
  end

  after do
    Timecop.return
  end

  describe '#headers' do
    subject { instance.headers }
    context "default" do
      it { should have_key 'SendingTime' }
    end

    context "merging keys" do
      let(:headers) { { "OtherField" => "test" } }
      it { should have_key 'SendingTime' }
      it { should have_key 'OtherField' }
    end
  end

  describe '#all_have_values?' do
    subject { instance.all_have_values?(hash, keys) }

    let(:key) { 'SomeField' }
    let(:keys) { [key] }
    
    context 'when the field is not included' do
      let(:hash) { { 'SomeOtherField' => 1 } }
      it { should be_false }
    end
    
    context 'when the field is included' do
      context 'but the value is empty' do
        let(:hash) { { key => nil } }
        it { should be_false }
      end
      
      context 'but the value is included' do
        let(:hash) { { key => 1 } }
        it { should be_true }
      end
    end
  end

  describe '#headers_are_valid?' do
    subject { instance.headers_are_valid? }
    before { schema.should_receive(:required_header_field_names).and_return([]) }
    it { should be_true }
  end

  describe '#properties_are_valid?' do
    subject { instance.properties_are_valid? }
    before { schema.should_receive(:required_field_names_for_message).with(message_type).and_return([]) }
    it { should be_true }
  end

  describe '#valid?' do
    subject { instance.valid? }
    before do
      instance.should_receive(:headers_are_valid?).and_return(true)
      instance.should_receive(:properties_are_valid?).and_return(true)
    end
    it { should be_true }
  end

  describe '#fixify' do
    let(:hash) { properties }
    let(:action!) { instance.fixify(hash) }
    subject { action! }

    context "with nothing" do
      it { should eq [] }
    end

    context "string field" do
      let(:properties) { {"StringField" => "Hello"} }
      it { should eq ["12=Hello"] }
    end

    context "boolean field" do
      let(:properties) { {"BooleanField" => true} }
      it { should eq ["11=Y"] }

      context "when false" do
        let(:properties) { {"BooleanField" => false} }
        it { should eq ["11=N"] }
      end
    end

    context "utc field" do
      let(:properties) { {"UtcField" => current_time} }
      it { should eq ["13=20130101-00:00:00.000"] }
    end

    context "mix" do
      let(:properties) { {"UtcField" => current_time, "StringField" => "Hello", "BooleanField" => true} }
      it { should eq ["13=20130101-00:00:00.000", "12=Hello", "11=Y"] }
    end

    context "with an invalid field" do
      let(:properties) { {'Geschwindigkeitsbegrenzung' => 60} }

      context "with strict enabled (default)" do
        before { instance.schema.should_receive(:field_number).with(properties.keys.first, true).and_raise(Damage::UnknownFieldNameError) }
        specify{ expect{ action! }.to raise_error }
      end

      context "with strict disabled" do
        before { instance.strict = false }
        it { should eq [] }
      end
    end
  end

  describe "#body" do
    subject { instance.body }

    context "default" do
      it { should eq "35=0" + Damage::SOH + "10=20130101-00:00:00.000" + Damage::SOH }
    end

    context "with extra headers and properties" do
      let(:headers) { {"BooleanField" => true } }
      let(:properties) { {"StringField" => "test" } }
      it { should eq "35=0" + Damage::SOH + "11=Y" + Damage::SOH + "10=20130101-00:00:00.000" + Damage::SOH + "12=test" + Damage::SOH}
    end
  end

  describe "#first_fields" do
    subject { instance.first_fields }

    context "default" do
      it { should eq "8=FIX.4.2" + Damage::SOH + "9=30" + Damage::SOH }
    end

    context "with extra headers and properties" do
      let(:headers) { {"BooleanField" => true } }
      let(:properties) { {"StringField" => "test" } }
      it { should eq "8=FIX.4.2" + Damage::SOH + "9=43" + Damage::SOH }
    end
  end

  describe "#message_without_checksum" do
    subject { instance.message_without_checksum }
    before do
      instance.stub(:first_fields) { "8=FIX.4.2" + Damage::SOH }
      instance.stub(:body) { "10=test" + Damage::SOH }
    end

    it { should eq "8=FIX.4.2" + Damage::SOH + "10=test" + Damage::SOH }
  end

  describe "#checksum" do
    let(:str) { "Test" }
    subject { instance.checksum(str) }

    it { should eq "10=160" + Damage::SOH }

    context "string with SOH" do
      let(:str) { "Test" + Damage::SOH }
      it { should eq "10=161" + Damage::SOH }
    end
  end

  describe "#full_message" do
    subject { instance.full_message }
    let(:headers) { {"BooleanField" => true } }
    let(:properties) { {"StringField" => "test" } }
      it { should eq "8=FIX.4.2" + Damage::SOH + "9=43" + Damage::SOH +
           "35=0" + Damage::SOH + "11=Y" + Damage::SOH +
           "10=20130101-00:00:00.000" + Damage::SOH + "12=test" + Damage::SOH +
           "10=211" + Damage::SOH}
  end

  describe "#to_s" do
    subject { instance.to_s }
    let(:properties) { {"StringField" => "test" } }

    it { should eq "0: #{properties.to_s}" }
  end
end
