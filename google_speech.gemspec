# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'google_speech/version'

Gem::Specification.new do |gem|
  gem.name          = "google_speech"
  gem.version       = GoogleSpeech::VERSION
  gem.authors       = ["Andrew Kuklewicz"]
  gem.email         = ["andrew@prx.org"]
  gem.description   = %q{This is a gem to call the google speech api.}
  gem.summary       = %q{This is a gem to call the google speech api.}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_dependency "excon"
end
