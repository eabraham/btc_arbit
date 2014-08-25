#require "rest_client"
#require "OpenSSL"
#require "Base64"
#require "JSON"
require 'kraken_ruby'
module RbtcArbitrage
  module Clients
    class KrakenClient
      include RbtcArbitrage::Client

      # return a symbol as the name
      # of this exchange
      def exchange
        :kraken
      end

      def interface
        @interface||=Kraken::Client.new(ENV['KRAKEN_KEY'], ENV['KRAKEN_SECRET'])
      end

      # Returns an array of Floats.
      # The first element is the balance in BTC;
      # The second is in USD.
      def balance
	response = interface.balance
	if (response.keys.include?("USD") || response.keys.include?("XXBT"))
	  btc_balance = response["XXBT"].to_f
          usd_balance = response["USD"].to_f
        else
	  btc_balance = 0.0
	  usd_balance = 0.0
	end

        #return [btc_balance, usd_balance]
        return [100,100]
      end

      # Configures the client's API keys.
      def validate_env
        validate_keys :kraken_key, :kraken_secret
	kraken = interface
      end

      # `action` is :buy or :sell
      def trade action
	#price(action) unless @price #memoize
        #bid_ask=action==:buy ? "bid":"ask"
        bid_ask=action==:buy ? :ask : :bid

        opts = {
             pair: 'XXBTZUSD',
	     type: action.to_s,
             ordertype: 'market',
	     volume: @options[:volume]
	}

        interface.add_order(opts)
	r_json = JSON.parse(response)

      end

      # `action` is :buy or :sell
      # Returns a Numeric type.
      def price action
        bid_ask=action==:buy ? :ask : :bid
	return @price[:bid] if @price && @price[:bid] #memoize
	return @price[:ask] if @price && @price[:ask] #memoize

        response = interface.ticker("XXBTZUSD")
        r_json = (response)
	if (r_json["XXBTZUSD"])
	  if bid_ask==:ask
            rate = r_json["XXBTZUSD"]["a"][0].to_f
	  elsif bid_ask==:bid
	    rate = r_json["XXBTZUSD"]["b"][0].to_f
	  end
	else
          rate = 0
	end

	@price[bid_ask] = rate
      end

      # Transfers BTC to the address of a different
      # exchange.
      def transfer client
	if @options[:verbose]
	  error = "Kraken does not have a 'transfer' API.\n"
	  error << "You must transfer bitcoin manually."
	  @options[:logger].error error
        end
      end
      # If there is an API method to fetch your
      # BTC address, implement this, otherwise
      # remove this method and set the ENV
      # variable [this-exchange-name-in-caps]_ADDRESS
    end
  end
end
