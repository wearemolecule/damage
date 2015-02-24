# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'damage/version'

Gem::Specification.new do |spec|
  spec.name          = "damage"
  spec.version       = Damage::VERSION
  spec.authors       = ["Adam Sunderland"]
  spec.email         = ["iterion@gmail.com"]
  spec.description   = %q{Damage is a FIX (Financial Information eXchange) Client using Celluloid}
  spec.summary       = %q{FIX Client for Ruby}
  spec.homepage      = ""
  spec.license       = "Apache"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "activesupport", ">= 3.2.16"
  spec.add_dependency "celluloid"
  spec.add_dependency "celluloid-io"
  spec.add_dependency "nokogiri"
  spec.add_dependency "thor"
  spec.add_dependency "tzinfo",        ">= 0.3.38"
  spec.add_dependency "highline"

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rspec", "~> 2.14.1"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "timecop"
  spec.add_development_dependency "pry-nav"
end
