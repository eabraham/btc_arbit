# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rbtc_arbitrage/version'

Gem::Specification.new do |spec|
  spec.name          = "rbtc_arbitrage"
  spec.version       = RbtcArbitrage::VERSION
  spec.authors       = ["Hank Stoever"]
  spec.email         = ["hstove@gmail.com"]
  spec.description   = %q{A gem for conducting arbitrage with Bitcoin.}
  spec.summary       = %q{A gem for conducting arbitrage with Bitcoin.}
  spec.homepage      = "https://github.com/hstove/rbtc_arbitrage"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)

  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "bundler", "~> 1.3"
  spec.add_dependency "rake", "10.1.1"

  spec.add_dependency "faraday", "0.8.8"
  spec.add_dependency "bitstamp"#, {:git => "http://github.com/kojnapp/bitstamp.git"}
  spec.add_dependency "activemodel", ">= 3.1"
  spec.add_dependency "activesupport", ">= 3.1"
  spec.add_dependency "thor"
  spec.add_dependency "btce", '0.2.4'
  spec.add_dependency "stathat"
  spec.add_dependency "coinbase", '2.1.0'
  spec.add_dependency "pony"
  spec.add_dependency "tco", "0.1.0"
  #spec.add_dependency "bitstamp-rbtc-arbitrage"
  spec.add_dependency "json"
  #spec.add_dependency "base64"
  #spec.add_dependency "openssl"
  spec.add_dependency "rest_client"
end
