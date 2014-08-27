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

      def hmac_512(msg)
	hmac = HMAC::SHA1.new(ENV['LAKEBTC_KEY'])
	signature = hmac.update(msg)
	Base64.encode64("#{ENV['LAKEBTC_ACCESS_KEY']}:#{hmac.update(msg).to_s}").chomp.gsub( /\n/, '' )
      end

      # Returns an array of Floats.
      # The first element is the balance in BTC;
      # The second is in USD.
      def balance
        #return [100,100]
	tonce=DateTime.now.strftime('%Q')
	id = 1
	values   = ("tonce=#{tonce}&"+
			        "accesskey=#{ENV['LAKEBTC_ACCESS_KEY']}&"+
                                "requestmethod=post&"+
                                "id=#{id}&"+
                                "method=getAccountInfo&"+
                                "params=")
        sign = hmac_512(values)

	headers  = {'Json-Rpc-Tonce' => tonce,
		    'Authorization'=> "Basic #{sign}"}
        params = {'username':ENV['ROCK_USERNAME'],
		  'password':ENV['ROCK_PASSWORD'],
                  'api_key':ENV['ROCK_KEY'],
	          'type_of_currency':'BTCUSD'}

	response = RestClient.post("https://www.therocktrading.com/api/get_balance", params.to_json, headers)
	r_json = JSON.parse(response)
	binding.pry
	if (r_json.keys.include?("balance"))
      	  btc_balance = r_json["balance"]["BTC"].to_f
          usd_balance = r_json["balance"]["USD"].to_f
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
        validate_keys :lakebtc_access_key, :lakebtc_key
      end

      # `action` is :buy or :sell
      def trade action
	bid_ask=action==:buy ? :ask : :bid
	p = @price[:bid] if @price && @price[:bid] #memoize
	p = @price[:ask] if @price && @price[:ask] #memoize
	p = price(action) unless p
        bid_ask=action==:buy ? "buyOrder":"sellOrder"
	volume = @options[:volume]

        tonce=DateTime.now.strftime('%Q')
        id = 1
	values   = ("tonce=#{tonce}&"+
                    "accesskey=#{ENV['LAKEBTC_ACCESS_KEY']}&"+
		    "requestmethod=post&"+
		    "id=#{id}&"+
		    "method=#{bid_ask}&"+
		    "params=#{[p,volume,'USD'].split(',')}")
	sign = hmac_512(values)

	headers  = {'Json-Rpc-Tonce' => tonce,
		    'Authorization'=> "Basic #{sign}"}
	response = RestClient.post("https://www.LakeBTC.com/api_v1", {params:[p,volume,'USD'],method:"#{bid_ask}",id:id}.to_json, headers)

      end

      # `action` is :buy or :sell
      # Returns a Numeric type.
      def price action
	bid_ask=action==:buy ? :ask : :bid
	return @price[:bid] if @price && @price[:bid] #memoize
        return @price[:ask] if @price && @price[:ask] #memoize
        response = RestClient.get "https://www.LakeBTC.com/api_v1/ticker"
	r_json = JSON.parse(response)

        if (r_json.keys.include?("USD"))
	  if bid_ask==:ask
            rate = r_json["USD"]["ask"].to_f
          elsif bid_ask==:bid
            rate = r_json["USD"]["bid"].to_f
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
      def address

        tonce=DateTime.now.strftime('%Q')
        id = 1
        values   = ("tonce=#{tonce}&"+
	            "accesskey=#{ENV['LAKEBTC_ACCESS_KEY']}&"+
		    "requestmethod=post&"+
		    "id=#{id}&"+
		    "method=getAccountInfo&"+
		    "params=")
	sign = hmac_512(values)
							
        headers  = {'Json-Rpc-Tonce' => tonce,
		    'Authorization'=> "Basic #{sign}"}
	response = RestClient.post("https://www.LakeBTC.com/api_v1", {params:[],method:"getAccountInfo",id:id}.to_json, headers)
	r_json = JSON.parse(response)
	if (r_json.keys.include?("profile"))
          btc_address = r_json["profile"]["btc_deposit_addres"]
	else
	  btc_address = ""
	end

	return btc_address
      end
    end
  end
end
