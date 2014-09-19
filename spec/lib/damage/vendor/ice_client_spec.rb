require 'spec_helper'

describe Damage::Vendor::IceClient do
  let(:mixin) { self.described_class }
  let(:klass) { Class.new(Object) do; end }
  let(:instance) { klass.new }
  before { klass.send(:include, mixin) }


  shared_context "operating window" do

    before do
      instance.tap do |t|
        def t.heartbeat_interval
          30
        end
      end

      # Time.any_instance.stub(:to_s) do
      class ::Time
        def to_s
          strftime('%a, %Y-%b-%d %I:%M:%S %p')
        end
      end
    end
  end

  describe '#in_operating_window?' do
    include_context "operating window"

    subject { instance.in_operating_window?(time) }

    context 'on a weekend' do
      context 'before Sunday at 5pm' do
        let(:time) { Time.utc(2014, 9, 14, 20, 0, 0).in_time_zone("Eastern Time (US & Canada)") } # Sun, 4pm
        it { should be_false }
      end

      context 'after Sunday at 5pm' do
        let(:time) { Time.utc(2014, 9, 14, 21, 27, 0).in_time_zone("Eastern Time (US & Canada)") } # Sun, 5:27
        it { should be_true }
      end
    end

    context 'on a weekday' do
      context 'before 6:29:30pm' do
        let(:time) { Time.utc(2014, 9, 11, 13, 0, 0).in_time_zone("Eastern Time (US & Canada)") } # Thu, 9am
        it { should be_true }
      end

      context 'between 6:27:30pm and 6:28:00pm' do
        let(:time) { Time.utc(2014, 9, 16, 22, 27, 37).in_time_zone("Eastern Time (US & Canada)") }
        it { should be_true }
      end

      context 'between 6:30:00pm and 7:30:00pm' do
        let(:time) { Time.utc(2014, 9, 16, 22, 32, 1).in_time_zone("Eastern Time (US & Canada)") }
        it { should be_false, "expected #{time} to not be in the window" }
      end

      context 'Friday at 2 p.m. EST' do
        let(:time) { Time.utc(2014, 9, 19, 18, 0, 0).in_time_zone("Eastern Time (US & Canada)") }
        it { should be_true }
      end

      context 'Friday at 6:30 p.m. EST' do
        let(:time) { Time.utc(2014, 9, 19, 22, 30, 0).in_time_zone("Eastern Time (US & Canada)") }
        it { should be_false, "expected #{time} to not be in the operating window" }
      end

      context 'after 7:30pm' do
        context 'Mon-Thu' do
          let(:time) { Time.utc(2014, 9, 16, 23, 32, 1).in_time_zone("Eastern Time (US & Canada)") }
          it { should be_true }
        end

        context 'on Fridays after 7:30' do
          let(:time) { Time.utc(2014, 9, 12, 23, 32, 1).in_time_zone("Eastern Time (US & Canada)") }
          it { should be_false }
        end
      end
    end
  end

  describe '#in_maintenance_window?' do
    include_context 'operating window'

    subject { instance.in_maintenance_window?(time) }

    context 'on a weekend' do
      context 'before Sunday at 5pm' do
        let(:time) { Time.utc(2014, 9, 13, 13, 0, 0).in_time_zone("Eastern Time (US & Canada)") } # Sat, 9am
        it { should be_true, "expected #{time} to be in the window" }
      end

      context 'after Sunday at 5pm' do
        let(:time) { Time.utc(2014, 9, 14, 21, 27, 0).in_time_zone("Eastern Time (US & Canada)") }
        it { should be_false }
      end
    end

    context 'on a weekday' do
      context 'before 6:29:00pm' do
        let(:time) { Time.utc(2014, 9, 11, 13, 0, 0).in_time_zone("Eastern Time (US & Canada)") } # Thu, 9am
        it { should be_false }
      end

      context 'between 6:27:30pm and 6:28:00pm' do
        let(:time) { Time.utc(2014, 9, 16, 22, 27, 37).in_time_zone("Eastern Time (US & Canada)") }
        it { should be_false }
      end

      context 'between 6:30:00pm and 7:30:00pm' do
        let(:time) { Time.utc(2014, 9, 16, 22, 32, 1).in_time_zone("Eastern Time (US & Canada)") }
        it { should be_true, "expected #{time} to be in the window" }
      end

      context 'after 7:30pm' do
        context 'Mon-Thu' do
          let(:time) { Time.utc(2014, 9, 11, 0, 0, 0).in_time_zone("Eastern Time (US & Canada)") }
          it { should be_false }
        end

        context 'on Fridays' do
          let(:time) { Time.utc(2014, 9, 13, 0, 0, 0).in_time_zone("Eastern Time (US & Canada)") }
          it { should be_true, "expected #{time} to be in the window" }
        end
      end
    end
  end

  # describe '#_within_time_range?' do
  #   subject { instance._within_time_range?(time) }
  # end

  describe '#_within_weekday_operating_range?' do
    include_context "operating window"

    subject { instance._within_weekday_operating_range?(time) }

    context 'on a weekend' do
      let(:time) { Time.utc(2014, 9, 13, 13, 0, 0).in_time_zone("Eastern Time (US & Canada)") } # Sat, 9am
      it { should be_false }
    end

    context 'on a weekday' do
      context 'before 6:30pm' do
        let(:time) { Time.utc(2014, 9, 11, 13, 0, 0).in_time_zone("Eastern Time (US & Canada)") } # Thu, 9am
        it { should be_true }
      end

      context 'between 6:30pm and 7:30pm EST' do
        let(:time) { Time.utc(2014, 9, 16, 23, 0, 0).in_time_zone("Eastern Time (US & Canada)") } # Tues, 7pm
        it { subject.should be_false }
      end

      context 'after 7:30pm' do
        context 'Mon-Thu' do
          let(:time) { Time.utc(2014, 9, 12, 0, 0, 0).in_time_zone("Eastern Time (US & Canada)") } # Thu, 8pm
          it { should be_true }
        end

        context 'on Fri' do
          let(:time) { Time.utc(2014, 9, 13, 0, 0, 0).in_time_zone("Eastern Time (US & Canada)") } # Fri, 8pm
          it { should be_false }
        end
      end
    end
  end

  describe '#_within_weekend_operating_range?' do
    include_context "operating window"

    subject { instance._within_weekend_operating_range?(time) }

    context 'on a weekday' do
      let(:time) { Time.utc(2014, 9, 11, 13, 0, 0).in_time_zone("Eastern Time (US & Canada)") }
      it { should be_false }
    end

    context 'on a saturday' do
      let(:time) { Time.utc(2014, 9, 13, 13, 0, 0).in_time_zone("Eastern Time (US & Canada)") } # Sat, 9am
      it { should be_false }
    end

    context 'on a sunday' do
      context 'before 5pm' do
        let(:time) { Time.utc(2014, 9, 14, 13, 0, 0).in_time_zone("Eastern Time (US & Canada)")} # Sun, 9am
        it { should be_false }
      end

      context 'after 5pm' do
        let(:time) { Time.utc(2014, 9, 14, 22, 0, 0).in_time_zone("Eastern Time (US & Canada)")} # Sun, 6pm
        it { should be_true }
      end
    end
  end

#  describe '#tick!' do
#    def action!
#      yield if block_given?
#      instance.tick!
#    end
#    let(:base_date) { Date.new(2014, 8, 7).to_time } # a Thursday

#    before do
#      Timecop.travel(tick_time)
#
#      # define some of the API for Damage::Client::Base
#      instance.tap do |i|
#        def i.heartbeat_interval
#          30
#        end
#        def i.send_heartbeat; end
#        def i.send_logon; end
#        def i.send_logout; end
#      end
#    end
#
#    after do
#      Timecop.return
#    end
#
#    shared_examples_for 'does nothing' do
#      it do
#        action! do
#          expect(instance).not_to receive(:send_heartbeat)
#          expect(instance).not_to receive(:send_logon)
#          expect(instance).not_to receive(:send_logout)
#        end
#      end
#    end
#
#    context 'when the client is logged out' do
#      before do
#        instance.stub(:logged_out?){ true }
#      end
#
#      context 'and the call comes during the operating window' do
#        let(:tick_time) { base_date + 9.hours }
#
#        it 'issues a logon' do
#          action! do
#            expect(instance).to receive(:send_logon)
#          end
#        end
#      end
#
#      context 'and the call comes outside the operating window' do
#        let(:tick_time) { base_date + 2.days }
#        it_should_behave_like 'does nothing'
#      end
#    end
#
#    context 'when the client is logged in' do
#      before do
#        instance.stub(:logged_out?){ false }
#      end
#
#      context 'and the call comes during the operating window' do
#        let(:tick_time) { base_date + 9.hours }
#
#        it 'sends a heartbeat' do
#          action! do
#            expect(instance).to receive(:send_heartbeat)
#          end
#        end
#      end
#
#      context 'and the call comes close to the end of the operating window' do
#        let(:tick_time) { base_date + 18.hours + 29.minutes + 45.seconds} # 18:28:45, i.e. 15 s before the end of the operating window
#
#        it 'sends a logout' do
#          action! do
#            expect(instance).to receive(:send_logout)
#          end
#        end
#      end
#
#      context 'and the call comes outside the operating window' do
#        let(:tick_time) { base_date + 2.days }
#
#        it 'sends a logout' do
#          action! do
#            expect(instance).to receive(:send_logout)
#          end
#        end
#      end
#    end
#  end

#  describe '#request_missing_messages' do
#    include_context "operating window"
#
#    let(:action!) { instance.request_missing_messages }
#    subject { nil }
#
#    let(:persistence) { double }
#    let(:schema) { Damage::Schema.new("schemas/FIX44.xml") }
#
#    # before do
#    #  instance.stub(persistence: persistence, default_headers: {}, strict?: false, socket: double, schema: schema, _info: nil)
#    # end
#
#    context 'when there are missing messages' do
#      before do
#        persistence.stub(missing_message_ranges: [[6,8]])
#        instance.persistence = persistence
#      end
#
#      specify do
#        expect(instance).to receive(:send_message) do |socket, message|
#          message.should match %r{568=[\da-f]+}
#          message.should match %r{569=0}
#          message.should match %r{263=1}
#          message.should match %r{580=1}
#          message.should match %r{75=\d{4}-\d\d-\d\d}
#          message.should match %r{60=\d{8}-\d\d:\d\d:\d\d\.\d\d\d}
#          true
#        end
#
#        expect(action!).to be_true
#      end
#    end
#
#    context 'when there are not any missing messages' do
#      before do
#        persistence.stub(missing_message_ranges: [])
#      end
#
#      specify do
#        expect(instance).to receive(:send_message) do |socket, message|
#          message.should match %r{568=[\da-f]+}
#          message.should match %r{569=0}
#          message.should match %r{263=1}
#          message.should match %r{580=1}
#          message.should match %r{75=\d{4}-\d\d-\d\d}
#          message.should match %r{60=\d{8}-\d\d:\d\d:\d\d\.\d\d\d}
#          true
#        end
#
#        expect(action!).to be_true
#      end
#    end
#  end
end
