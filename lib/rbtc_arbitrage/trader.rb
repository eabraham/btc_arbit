module RbtcArbitrage
  class Trader
    include RbtcArbitrage::TraderHelpers::Notifier
    include RbtcArbitrage::TraderHelpers::Logger

    attr_reader :buy_client, :sell_client, :received
    attr_accessor :buyer, :seller, :options

    def initialize config={}
      opts = {}
      config.each do |key, val|
        opts[(key.to_sym rescue key) || key] = val
      end
      @buyer   = {}
      @seller  = {}
      @options = {}
      set_key opts, :volume, 0.01
      set_key opts, :cutoff, 2
      set_key opts, :trade_retries, 20

      default_logger = Logger.new("log.log")#Logger.new($stdout)
      default_logger.datetime_format = "%^b %e %Y %l:%M:%S %p %z"
      logger = Logger.new($stdout)
      logger.datetime_format = "%^b %e %Y %l:%M:%S %p %z"
      set_key opts, :logger, ENV['LOGFILE']!="true" ? logger : default_logger
      set_key opts, :verbose, true
      set_key opts, :live, false
      set_key opts, :repeat, nil
      set_key opts, :notify, false
      @buy_exchanges = opts[:buyer].split(",") || [:bitstamp]
      @buy_clients = getExchanges(@buy_exchanges)
      @sell_exchanges = opts[:seller].split(",") || [:campbx]
      @sell_clients = getExchanges(@sell_exchanges)
      selectExchanges
      self
    end

    def getExchanges(exchange_names)
      exchange_names.map do |exchange|
	client = client_for_exchange(exchange)
        client.validate_env
	client
      end
    end

    def set_key config, key, default
      @options[key] = config.has_key?(key) ? config[key] : default
    end

    def trade
      fetch_prices
      log_info if options[:verbose]
      if options[:live] && options[:cutoff] > @percent
        logger.info "Real profit (#{@percent.round(2)}%) is less than cutoff (#{options[:cutoff].round(2)}%)"
      else
        execute_trade if options[:live]
      end

      if @options[:repeat]
        trade_again
      end

      self
    end

    def selectExchanges
      @buy_client = @buy_clients[0]
      @sell_client = @sell_clients[0]
      logger.info "Exchanges considered for Buy:" if @options[:verbose]
      @buy_clients.each do |exchange|
	logger.info "#{exchange.exchange} balance: $#{color(exchange.balance[1])} USD buy price: $#{color(exchange.price(:buy))}" if @options[:verbose]
	if exchange.balance[1] > @options[:volume] * exchange.price(:buy) * 1.001
          #sufficuent USD to trade
          if exchange.price(:buy) < @buy_client.price(:buy)
            @buy_client=exchange
	  end
	end
      end
      logger.info "Exchanges considered for Sell:" if @options[:verbose]
      @sell_clients.each do |exchange|
	logger.info "#{exchange.exchange} balance: #{color(exchange.balance[0])} BTC sell price: #{color(exchange.price(:sell))}" if @options[:verbose]
	if exchange.balance[0] > @options[:volume] * 1.001
          #sufficuent BTC to trade
          if exchange.price(:sell) > @sell_client.price(:sell)
            @sell_client=exchange
	  end
        end
      end
    end

    def trade_again
      sleep @options[:repeat]
      logger.info " - " if @options[:verbose]
      begin
        @buy_clients = getExchanges(@buy_exchanges)
        @sell_clients = getExchanges(@sell_exchanges)
        selectExchanges
        #@buy_client = @buy_client.class.new(@options)
        #@sell_client = @sell_client.class.new(@options)
        trade
      rescue Exception => e
        trade_again
      end
    end

    def execute_trade
      fetch_prices unless @paid
      raise SecurityError, "--live flag is false. Not executing trade." unless options[:live]
      get_balance
      if @percent > @options[:cutoff]
        buy_and_transfer!
      else
        logger.info "Not trading live because cutoff is higher than profit." if @options[:verbose]
      end
    end

    def fetch_prices
      logger.info "Fetching exchange rates with sufficient funds" if @options[:verbose]
      buyer[:price] = @buy_client.price(:buy)
      seller[:price] = @sell_client.price(:sell)
      prices = [buyer[:price], seller[:price]]

      calculate_profit
    end

    def get_balance
      @seller[:btc], @seller[:usd] = @sell_client.balance
      @buyer[:btc], @buyer[:usd] = @buy_client.balance
    end

    def validate_env
      [@sell_client, @buy_client].each do |client|
        client.validate_env
      end
      if options[:notify]
        ["PASSWORD","USERNAME","EMAIL"].each do |key|
          key = "SENDGRID_#{key}"
          unless ENV[key]
            raise ArgumentError, "Exiting because missing required ENV variable $#{key}."
          end
        end
        setup_pony
      end
    end

    def client_for_exchange market
      market = market.to_sym unless market.is_a?(Symbol)
      clazz = RbtcArbitrage::Clients.constants.find do |c|
        clazz = RbtcArbitrage::Clients.const_get(c)
        clazz.new.exchange == market
      end
      begin
        clazz = RbtcArbitrage::Clients.const_get(clazz)
        clazz.new @options
      rescue TypeError => e
        raise ArgumentError, "Invalid exchange - '#{market}'"
      end
    end

    private

    def calculate_profit
      buyer_fee = buyer[:fee] ? 1+buyer[:fee] : 1.005
      seller_fee = seller[:fee] ? 1-seller[:fee] : 0.995
      @paid = buyer[:price] * buyer_fee * @options[:volume]
      @received = seller[:price] * seller_fee * @options[:volume]
      @percent = ((@received/@paid - 1) * 100).round(2)
    end

    def buy_and_transfer!
      if @paid > buyer[:usd] || @options[:volume] > seller[:btc]
        logger.info "Not enough funds. Cancelling." if options[:verbose]
      else
        logger.info "Trading live!" if options[:verbose]
	#perform action on exchnage with lowest volume first
	#confirm that trade completes
	#If trade does not complete in 10 seconds cancel order and prevent other side of arbitrage
	if @buy_client.trade_volume <= @sell_client.trade_volume
          executed = @buy_client.buy
          executed = @sell_client.sell if executed
          @buy_client.transfer @sell_client if executed
          notify if executed
	else
          executed = @sell_client.sell
          executed = @buy_client.buy if executed
          @buy_client.transfer @sell_client if executed
          notify if executed
	end
      end
    end

  end
end
