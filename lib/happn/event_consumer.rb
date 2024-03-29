require "bunny"
require "rabbitmq/http/client"

module Happn
  class EventConsumer
    def initialize(logger, configuration, subscription_repository)
      @configuration           = configuration
      @logger                  = logger
      @subscription_repository = subscription_repository
      @queue_name              = @configuration.rabbitmq_queue_name
      options                  = {
        host: @configuration.rabbitmq_host,
        port: @configuration.rabbitmq_port&.to_i,
        user: @configuration.rabbitmq_user,
        password: @configuration.rabbitmq_password,
        automatically_recover: true
      }.merge(@configuration.bunny_options || {})
      @connection              = Bunny.new(options)

      management_options = {
        username: @configuration.rabbitmq_user,
        password: @configuration.rabbitmq_password
      }.merge(@configuration.management_options || {})
      @management_client       = RabbitMQ::HTTP::Client.new("#{@configuration.rabbitmq_management_scheme || "http"}://#{@configuration.rabbitmq_host}:#{@configuration.rabbitmq_management_port}/", management_options)
    end

    def wait_until_connected
      connected = false
      while !connected
        begin
          connect
          connected = true
        rescue Bunny::TCPConnectionFailedForAllHosts
          @logger.warn("RabbitMQ connection failed, try again in 1 second.")
          sleep 2
        end
      end
    end

    def start
      wait_until_connected
      consume
    end

    private

    def connect
      @connection.start
      channel_number                   = nil
      consumer_pool_size               = 1
      consumer_pool_abort_on_exception = true
      @channel                         = @connection.create_channel(channel_number, consumer_pool_size, consumer_pool_abort_on_exception)
      @channel.on_uncaught_exception do |exception|
        @configuration.on_error&.call(exception)
        @logger.error("An error occurred. Exiting events consumption.")
        exit(1)
      end
      @channel.basic_qos(@configuration.rabbitmq_prefetch_size)
      arguments                        = {}
      arguments["x-queue-mode"]        = @configuration.rabbitmq_queue_mode unless @configuration.rabbitmq_queue_mode.nil?
      @queue                           = @channel.queue(@queue_name, durable: true, arguments: arguments)
      exchange                         = @channel.send(:topic,
                                                       @configuration.rabbitmq_exchange_name,
                                                       durable: @configuration.rabbitmq_exchange_durable)

      routing_keys = @subscription_repository.find_all.map do | subscription |
        subscription.query.to_routing_key
      end
      routing_keys.uniq.each do | routing_key |
        @logger.info("Bind exchange to queue with routing key : #{routing_key}")
        @queue.bind(exchange, routing_key: routing_key)
      end

      unbind_useless_routing_keys(@queue, exchange, routing_keys)

      @logger.info("Ready!")
    end

    def consume
      options  = {
        manual_ack: true,
        block: true
      }
      @queue.subscribe(options) do | delivery_info, _properties, event |
        begin
          handle_message(event, delivery_info)
        rescue => exception
          handle_exception(exception, delivery_info)
        end
      end
    end

    def handle_message(message, delivery_info)
      event         = Event.new(JSON.parse(message))
      subscriptions = @subscription_repository.find_subscriptions_for(event)

      @logger.info("Executing #{subscriptions.size} handlers for event '#{event.name}' with id: #{event.id}.")
      subscriptions.each do | subscription |
        projector = subscription.projector
        handler   = subscription.handler
        projector.instance_exec(event, &handler)
      end
      @channel.acknowledge(delivery_info.delivery_tag, false)
    end

    def handle_exception(exception, delivery_info)
      @logger.error(exception)
      @channel.reject(delivery_info.delivery_tag, true)
      @logger.fatal("Can't handle event, exit.")
      raise exception
    end

    private

    def unbind_useless_routing_keys(queue, exchange, useful_routing_keys)
      all_routing_keys = find_all_routing_keys_of(queue)
      keys_to_remove   = all_routing_keys - useful_routing_keys
      keys_to_remove.each do | routing_key |
        @queue.unbind(exchange, routing_key: routing_key)
      end
    end

    def find_all_routing_keys_of(queue)
      @management_client.list_queue_bindings("/", queue.name).map do | binding |
        binding.routing_key
      end
    end
  end
end
