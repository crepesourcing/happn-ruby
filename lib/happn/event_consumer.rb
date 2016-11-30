require "bunny"
require "rabbitmq/http/client"

module Happn
  class EventConsumer
    def initialize(logger, configuration, subscription_repository)
      @configuration           = configuration
      @logger                  = logger
      @subscription_repository = subscription_repository
      @queue_name              = @configuration.rabbitmq_queue_name
      @max_retries             = @configuration.max_retries
      @attempts                = 0
      @connection              = Bunny.new(host: @configuration.rabbitmq_host,
                                           port: @configuration.rabbitmq_port,
                                           user: @configuration.rabbitmq_user,
                                           password: @configuration.rabbitmq_password,
                                           automatically_recover: true)
      @management_client      = RabbitMQ::HTTP::Client.new("http://#{@configuration.rabbitmq_host}:#{@configuration.rabbitmq_management_port}/",
                                                           username: @configuration.rabbitmq_user,
                                                           password: @configuration.rabbitmq_password)
    end

    def start
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
      consume
    end

    private

    def connect
      @connection.start
      @channel = @connection.create_channel
      @queue   = @channel.queue(@queue_name, durable: true)
      exchange = @channel.send(:topic,
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
        block: true,
        arguments: {
          "x-queue-mode" => @configuration.rabbitmq_queue_mode
        }
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
      @attempts += 1
      if @attempts > @max_retries
        @logger.fatal("Max retry reached to handle event, exit.")
        exit(1)
      end
      @logger.fatal("Can't handle event, wait and retry.")
      sleep(2)
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
