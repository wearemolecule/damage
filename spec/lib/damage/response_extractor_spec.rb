require 'spec_helper'

describe Damage::ResponseExtractor do
  let(:klass) { self.described_class }
  let(:schema) { double("schema") }
  let(:heartbeat) { "8=FIX.4.2\u00019=00064\u000135=0\u000149=TTDS68BO\u000156=MOLECULEDTS\u000134=768\u000152=20140218-00:19:45.207\u000110=085\u0001" }
  let(:test_message) { heartbeat }

  let(:instance) { klass.new(schema, test_message) }

  describe '#extract_messages' do
    subject { instance.responses }

    describe "one message" do
      its(:length) { should eq 1 }
      it { subject.first.original_message.should eq heartbeat }
    end

    describe "two messages" do
      let(:test_message) { heartbeat * 2 }

      its(:length) { should eq 2 }
      it { subject.first.original_message.should eq heartbeat }
      it { subject.last.original_message.should eq heartbeat }
    end

    describe "two messages with short length" do
      let(:short_len_heartbeat) { "8=FIX.4.2\u00019=00062\u000135=0\u000149=TTDS68BO\u000156=MOLECULEDTS\u000134=768\u000152=20140218-00:19:45.207\u000110=085\u0001" }
      let(:test_message) { short_len_heartbeat + heartbeat }

      its(:length) { should eq 1 }
      it { subject.first.original_message.should eq heartbeat }
    end

    describe "two messages one with long length" do
      let(:long_len_heartbeat) { "8=FIX.4.2\u00019=00065\u000135=0\u000149=TTDS68BO\u000156=MOLECULEDTS\u000134=768\u000152=20140218-00:19:45.207\u000110=085\u0001" }
      let(:test_message) { long_len_heartbeat + heartbeat }

      its(:length) { should eq 1 }
      it { subject.first.original_message.should eq heartbeat }
    end
  end
end
