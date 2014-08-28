#require "rest_client"
#require "OpenSSL"
#require "Base64"
#require "JSON"

module RbtcArbitrage
  module Clients
    class RockClient
      include RbtcArbitrage::Client

      # return a symbol as the name
      # of this exchange
      def exchange
        :rock
      end

      # Returns an array of Floats.
      # The first element is the balance in BTC;
      # The second is in USD.
      def balance
        params = {'username' => ENV['ROCK_USERNAME'],
		  'password' => ENV['ROCK_PASSWORD'],
                  'api_key'  => ENV['ROCK_KEY']}

        btc_balance = 0.0
	usd_balance = 0.0

	response = RestClient.post("https://www.therocktrading.com/api/get_balance", params, {})
	r_json = JSON.parse(response)
	if (r_json.keys.include?("result"))
	  r_json["result"].each do |currency|
            if currency["currency"]=="BTC"
      	      btc_balance = currency["balance"].to_f
	    elsif currency["currency"]=="USD"
	      usd_balance = currency["balance"].to_f
            end
	  end
    	else
	  btc_balance = 0.0
	  usd_balance = 0.0
	end
        return [btc_balance, usd_balance]
      end

      def interface
      end

      # Configures the client's API keys.
      def validate_env
        validate_keys :rock_key, :rock_username, :rock_password
      end

      # `action` is :buy or :sell
      def trade action
	bid_ask=action==:buy ? :ask : :bid
	p = @price[:bid] if @price && @price[:bid] #memoize
	p = @price[:ask] if @price && @price[:ask] #memoize
	p = price(action) unless p
        bid_ask=action==:buy ? "S":"B" #reverse because its BTCUSD pair
	volume = @options[:volume]

        params = {'username' => ENV['ROCK_USERNAME'],
	          'password' => ENV['ROCK_PASSWORD'],
	          'api_key'  => ENV['ROCK_KEY'],
	          'fund_name'=> 'BTCUSD',
		  'order_type'=>bid_ask,
		  'amount'   => volume,
		  'price'    => p
	         }

	response = RestClient.post("https://www.therocktrading.com/api/place_order", params, {})

      end

      # `action` is :buy or :sell
      # Returns a Numeric type.
      def price action
	bid_ask=action==:buy ? :ask : :bid
	return @price[:bid] if !@price.nil? && !@price[:bid].nil? && bid_ask==:bid #memoize
        return @price[:ask] if !@price.nil? && !@price[:ask].nil? && bid_ask==:ask #memoize
        response = RestClient.get "https://www.therocktrading.com/api/tickers"
	r_json = JSON.parse(response)
        if (r_json.keys.include?("result") && r_json["result"].keys.include?("tickers"))
          @price[:ask]=r_json["result"]["tickers"]["BTCUSD"]["ask"].to_f
	  @price[:bid]=r_json["result"]["tickers"]["BTCUSD"]["bid"].to_f
        else
          @price = {:ask=>0, :bid=>0}
        end

	@price[bid_ask]
      end

      # Transfers BTC to the address of a different
      # exchange.
      def transfer client
        if @options[:verbose]
          error = "Rock Trading does not have a 'transfer' API.\n"
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
