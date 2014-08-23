#require "rest_client"
#require "OpenSSL"
#require "Base64"
#require "JSON"

module RbtcArbitrage
  module Clients
    class LakebtcClient
      include RbtcArbitrage::Client

      # return a symbol as the name
      # of this exchange
      def exchange
        :lakebtc
      end

      def hmac_512(msg, sec)
	digest = OpenSSL::Digest::Digest.new( 'sha512' )
        sec = Base64.decode64(sec)
        hmac = OpenSSL::HMAC.digest(digest, sec, msg)
	Base64.encode64( hmac ).chomp.gsub( /\n/, '' )
      end

      # Returns an array of Floats.
      # The first element is the balance in BTC;
      # The second is in USD.
      def balance
	values   = CGI::escape("nonce=#{Time.now.to_i}")

        sign = hmac_512(values,ENV['ANXPRO_SECRET'])

	headers  = {:content_type => "application/x-www-form-urlencoded",
		    :rest_key => "\u003C#{ENV['ANXPRO_KEY']}\u003E",
		    :rest_sign => "\u003C#{sign}\u003E"}
	response = RestClient.post "https://anxpro.com/api/2/money/info", values, headers
	r_json = JSON.parse(response)

	if (response["response"] == "success")
	  btc_balance = r_json["data"]["Wallets"]["BTC"]["Balance"]["value"].to_f
          usd_balance = r_json["data"]["Wallets"]["USD"]["Balance"]["value"].to_f
        else
	  btc_balance = 0.0
	  usd_balance = 0.0
	end

        return [btc_balance, usd_balance]
        return [100,100]
      end

      def interface
      end

      # Configures the client's API keys.
      def validate_env
        validate_keys :anxpro_key, :anxpro_secret
      end

      # `action` is :buy or :sell
      def trade action
	price(action) unless @price #memoize
        bid_ask=action==:buy ? "bid":"ask"
	volume = action==:buy ? @options[:volume]*10000000000 : @options[:volume]*100000
        values   = CGI::escape("nonce=#{Time.now.to_i}\u0026type=#{bid_ask}\u0026amount_int=#{volume}")

        sign = hmac_512(values,ENV['ANXPRO_SECRET'])
        headers  = {:content_type => "application/x-www-form-urlencoded",
                    :rest_key => "\u003C#{ENV['ANXPRO_KEY']}\u003E",
                    :rest_sign => "\u003C#{sign}\u003E"}
        response = RestClient.post "https://anxpro.com/api/2/BTCUSD/money/order/add/", values, headers
        r_json = JSON.parse(response)

        if (response["response"] == "success")
        end
      end

      # `action` is :buy or :sell
      # Returns a Numeric type.
      def price action
	bid_ask=action==:buy ? :ask : :bid
	return @price[:bid] if @price && @price[:bid] #memoize
        return @price[:ask] if @price && @price[:ask] #memoize
        response = RestClient.get "https://www.LakeBTC.com/api_v1/ticker"
	r_json = JSON.parse(response)

        if (r_json.keys.includes?("USD"))
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
        values   = CGI::escape("nonce=#{Time.now.to_i}\u0026address=#{client.address}\u0026amount_int=#{@options[:volume]*10000000000}")

	sign = hmac_512(values,ENV['ANXPRO_SECRET'])
	headers  = {:content_type => "application/x-www-form-urlencoded",
	:rest_key => "\u003C#{ENV['ANXPRO_KEY']}\u003E",
	:rest_sign => "\u003C#{sign}\u003E"}
	response = RestClient.post "https://anxpro.com/api/2/money/BTC/send_simple", values, headers
	r_json = JSON.parse(response)

	if (response["response"] == "success")
	end
      end

      # If there is an API method to fetch your
      # BTC address, implement this, otherwise
      # remove this method and set the ENV
      # variable [this-exchange-name-in-caps]_ADDRESS
      def address
	values   = CGI::escape("nonce=#{Time.now.to_i}")

	sign = hmac_512(values,ENV['ANXPRO_SECRET'])
	headers  = {:content_type => "application/x-www-form-urlencoded",
	:rest_key => "\u003C#{ENV['ANXPRO_KEY']}\u003E",
	:rest_sign => "\u003C#{sign}\u003E"}
	response = RestClient.post "https://anxpro.com/api/2/money/BTC/send_simple", values, headers
	r_json = JSON.parse(response)

	if (response["response"] == "success")
	  btc_address = response["result"]["data"]["addr"]
        else
	  btc_address = ""
	end

	return btc_address

      end
    end
  end
end
