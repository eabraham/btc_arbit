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

      def open_orders
        orders = Bitstamp.orders.all
	return orders.map{|a| a.send(:id)}
      end

      def cancel_order id
        Bitstamp.orders.find(id).cancel!
      end

      def price action
        bid_ask=action==:buy ? :ask : :bid
	return @price[:bid] if @price && @price[:bid] && bid_ask==:bid #memoize
	return @price[:ask] if @price && @price[:ask] && bid_ask==:ask #memoize
	ticker = Bitstamp.ticker
        @price[:bid] = ticker.send(:bid).to_f
	@price[:ask] = ticker.send(:ask).to_f
	@trade_vol = ticker.send(:volume).to_f
        return @price[bid_ask]
      end

      def trade_volume
        return @trade_vol if !@trade_vol
	price :buy
	return @trade_vol
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
        binding.pry
	return response.send(:id)
      end

      def transfer other_client
        Bitstamp.withdraw_bitcoins({:amount=>@options[:volume], :address=>other_client.address})
      end
    end
  end
end
