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

    describe "failed parse" do
      let(:schema) { Damage::Schema.new("schemas/TTFIX42.xml") }
      let(:test_message) { "8=FIX.4.2\x019=00080\x0135=4\x0149=TTDS68BO\x0156=MOLECULEDTS\x0134=80\x0143=Y\x0152=20140304-15:17:26.954\x0136=81\x01123=Y\x0110=093\x018=FIX.4.2\x019=00426\x0135=8\x0143=Y\x01122=20140304-15:00:49.282\x0152=20140304-15:17:26.954\x0149=TTDS68BO\x0156=MOLECULEDTS\x0150=TTORDDS004001\x0157=NONE\x0134=81\x0155=ES\x0148=00A0CO00ESZ\x0110455=ESH4\x01167=FUT\x01207=CME\x0115=USD\x011=moleculedts\x0147=A\x01204=0\x0110553=MOLECULEDTS\x0118203=CME\x0118216=P10000\x01198=3DJZB\x0137=0G798X047\x0117=0G798X047:0\x0158=Created from existing\x01200=201403\x01151=5\x0114=0\x0154=1\x0140=2\x0177=O\x0159=0\x0111028=Y\x01150=0\x0120=0\x0139=0\x01442=1\x0144=1844.25\x0138=5\x016=0\x0160=20140304-15:00:48.925\x01146=0\x0110=219\x018=FIX.4.2\x019=00522\x0135=8\x0143=Y\x01122=20140304-15:00:49.483\x0152=20140304-15:17:26.954\x0149=TTDS68BO\x0156=MOLECULEDTS\x0150=TTORDDS004001\x0157=NONE\x0134=82\x0155=ES\x0148=00A0CO00ESZ\x0110455=ESH4\x01167=FUT\x01207=CME\x0115=USD\x011=moleculedts\x0147=A\x01204=0\x0110553=MOLECULEDTS\x01375=CME000A\x0118203=CME\x0118216=P10000\x01198=3DJZB\x0137=0G798X047\x0117=1ol8a1k1dgg1tl\x0158=Fill\x0110527=64375:M:100400TN0016679\x0116018=n1vrs0\x01200=201403\x0132=5\x01151=0\x0114=5\x0175=20140304\x0154=1\x0140=2\x0177=O\x0159=0\x0111028=Y\x01150=2\x0120=0\x0139=2" }

      its(:length) { should eq 2 }
    end
  end
end
