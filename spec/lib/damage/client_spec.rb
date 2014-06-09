require 'spec_helper'

describe Damage::Client do
  # normally I like to use `self.described_class` let
  let(:klass) { Damage::Client }
  let(:listeners) { [] }
  # let(:options) { { server_ip: "127.0.0.1", port: 767676, schema_name: "FIX44", autostart: false } }
  let(:options) { { server_ip: "www.google.com", port: 80, schema_name: "FIX44", autostart: false } }
  let(:vendor) { :trading_tech }
  let(:initialize!) { klass.new(vendor, listeners, options) }

  around do |ex|
    Celluloid.boot
    ex.run
    Celluloid.shutdown
  end

  describe :class do
    # normally I wouldn't test this, but the module that the class receives most of
    # it's functionality from, Damage::Client::Base, also has #initialize defined,
    # with an arity of 2, so just being specific about that here
    specify { klass.instance_method(:initialize).arity.should eq -3 }

    describe '::new' do
      subject { initialize! }

      context 'sets the vendor' do
        it { should be_kind_of Damage::Vendor::TradingTechClient }
      end

      context 'attempts to include the customization module for the supplied vendor' do
        let(:vendor) { :ice }
        it { should be_kind_of Damage::Vendor::IceClient }
      end

      context 'when the customization cannot be found' do
        let(:vendor) { :foobar }
        it { should_not be_kind_of Damage::Vendor::IceClient }
        it do
          class Damage::Vendor::FooBarClient; end
          should_not be_kind_of Damage::Vendor::FooBarClient
        end
      end

      context 'bubbles up #initialize' do
        it { should be_a Damage::Client::Base }
      end
    end
  end

  describe :instance do
    let(:instance) { initialize! }

    subject { instance }

    it { should respond_to :vendor }
    it { should respond_to :vendor= }
  end
end
