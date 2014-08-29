module RbtcArbitrage
  module Clients
    class BitstampClient
      include RbtcArbitrage::Client

      def balance
        return @balance if @balance
        balances = Bitstamp.balance
        @balance = [balances["btc_available"].to_f, balances["usd_available"].to_f]
      end

      def validate_env
        validate_keys :bitstamp_key, :bitstamp_client_id, :bitstamp_secret
        Bitstamp.setup do |config|
          config.client_id = ENV["BITSTAMP_CLIENT_ID"]
          config.key = ENV["BITSTAMP_KEY"]
          config.secret = ENV["BITSTAMP_SECRET"]
        end
      end

      def exchange
        :bitstamp
      end

      def price action
        bid_ask=action==:buy ? :ask : :bid
	return @price[:bid] if @price && @price[:bid] #memoize
	return @price[:ask] if @price && @price[:ask] #memoize
        @price[bid_ask] = Bitstamp.ticker.send(bid_ask).to_f
      end

      def trade action
        bid_ask=action==:buy ? :ask : :bid
        price(action) unless @price #memoize
        multiple = {
          buy: 1,
          sell: -1,
        }[action]
        bitstamp_options = {
          "price" => (@price[bid_ask] + 0.001 * multiple).round(2),
          "amount" => @options[:volume]
        }
        response=Bitstamp.orders.send(action, bitstamp_options)
      end

      def transfer other_client
        Bitstamp.withdraw_bitcoins({:amount=>@options[:volume], :address=>other_client.address})
      end
    end
  end
end
