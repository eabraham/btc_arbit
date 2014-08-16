require 'bundler'
Dir.chdir("#{File.dirname(__FILE__)}/../") do
  Bundler.require(:default)
end
require 'bitstamp'
require 'thor'
require_relative 'rbtc_arbitrage/campbx.rb'
require 'btce'
require 'coinbase'
require 'pony'
require 'tco'
require 'stathat'
require 'rest_client'
require_relative 'rbtc_arbitrage/client.rb'
Dir["#{File.dirname(__FILE__)}/rbtc_arbitrage/trader/*.rb"].each { |f| require(f) }
Dir["#{File.dirname(__FILE__)}/rbtc_arbitrage/**/*.rb"].each { |f| require(f) }

module RbtcArbitrage
  def self.clients
    RbtcArbitrage::Clients.constants.collect do |c|
      RbtcArbitrage::Clients.const_get(c)
    end
  end
end
