require 'spec_helper'

describe 'ICEFIX44' do
  let(:schema) { Damage::Schema.new("schemas/ICEFIX44.xml") }
  let(:message) { "8=FIX.4.4\u00019=527\u000135=AE" }
  let(:instance) { Damage::Response.new(message, schema: schema) }

  subject { instance }

  it { should be_a Damage::Response }
  it { should respond_to :msg_type }
  it { should respond_to :orig_trade_i_d }
end
