require 'pry'
require 'timecop'
require 'celluloid/test'
require 'celluloid/rspec'
# require 'celluloid/probe'
require File.expand_path('../../lib/damage', __FILE__)
require File.expand_path('../../lib/damage/fake_fix_server', __FILE__)
Dir["./spec/support/**/*.rb"].sort.each {|f| require f}

Celluloid.shutdown_timeout = 1

RSpec.configure do |config|
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true
  config.filter_run :focus

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = 'random'

  unless ENV['VERBOSE']
    # quiet the log messages for specs
    Damage.configuration.logger = Class.new(Logger) do
      def add(*args, &block); end
    end.new($stdout) 
    $CELLULOID_DEBUG = false
    Celluloid.logger = nil
  end
end
