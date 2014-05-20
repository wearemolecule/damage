require 'spec_helper'

describe Damage::Vendor::IceClient do
  let(:mixin) { self.described_class }
  let(:klass) { Class.new(Object) do; end }
  let(:instance) { klass.new }
  before { klass.send(:include, mixin) }

  describe '#request_missing_messages' do
    subject { instance.request_missing_messages }

    let(:persistence) { double }
    let(:schema) { Damage::Schema.new("schemas/FIX44.xml") }

    before do
      instance.stub(persistence: persistence, default_headers: {}, strict?: false, socket: double, schema: schema, _info: nil)
      persistence.stub(missing_message_ranges: [])
      instance.should_receive(:send_message) do |socket, message|
        message.should match %r{568=[\da-f]+}
        message.should match %r{569=0}
        message.should match %r{263=1}
        message.should match %r{580=1}
        message.should match %r{75=\d{4}-\d\d-\d\d}
        message.should match %r{60=\d{8}-\d\d:\d\d:\d\d\.\d\d\d}
        true
      end
    end

    it { should be_true }
  end
end
