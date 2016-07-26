module Happn
  class EventConsumer
    def initialize
      @connection    = ::Bunny.new({
        host: ENV.fetch("RABBITMQ_HOST"),
        user: ENV.fetch("RABBITMQ_USER"),
        pass: ENV.fetch("RABBITMQ_PASSWORD"),
        port: ENV.fetch("RABBITMQ_PORT").to_i
        })
      @queue_name                = ENV.fetch("CONSUMER_QUEUE_NAME")
      @max_retries               = 5
      @attempts                  = 0
      @logger                    = Rails.logger
      projector_names            = ENV.fetch("PROJECTOR_NAMES")
      @subscriptions             = projectors_subscriptions(projector_names)
      @subscriptions_with_regexp = projectors_subscriptions_with_regexp(projector_names)
      @logger.debug("Projectors subscribed by name, #{@subscriptions}")
      @logger.debug("Projectors subscribed with regexp, #{@subscriptions_with_regexp}")
    end

    def start
      connected = false
      while !connected
        begin
          connect
          connected = true
        rescue Bunny::TCPConnectionFailedForAllHosts
          @logger.warn("RabbitMQ connection failed, try again in 1 second.")
          sleep 1
        end
      end
      consume
    end

    private

    def connect
      @connection.start
      @channel = @connection.create_channel
      @queue   = @channel.queue(@queue_name, durable: true)
      options  = {
        manual_ack: true,
        block: true
      }
      exchange = @channel.send(ENV.fetch("RABBITMQ_EXCHANGE_TYPE"),
        ENV.fetch("RABBITMQ_EXCHANGE_NAME"),
        durable: ENV.fetch("RABBITMQ_EXCHANGE_DURABLE") == "true"
      )
      @queue.bind(exchange)
      @logger.info("Ready!")
    end


    def consume
      @queue.subscribe(options) do |delivery_info, _properties, event|
        begin
          handle_message(event, delivery_info)
        rescue => exception
          handle_exception(exception, delivery_info)
        end
      end
    end

    def handle_message(raw_event, delivery_info)
      event               = JSON.parse(raw_event)
      event_subscriptions = projectors_for(event["meta"]["name"])

      event_subscriptions.each do |projector|
        data = event["data"]
        projector.handle_by_name(event, data)
        projector.handle_by_expression(event, data)
      end

      @channel.acknowledge(delivery_info.delivery_tag, false)
    end

    def projectors_for(event_name)
      projectors = @subscriptions[event_name] || []
      @subscriptions_with_regexp.each do | regexp_projector |
        projectors.push(regexp_projector) unless projectors.include?(regexp_projector)
      end
      projectors
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

    def projectors_subscriptions(projector_names)
      subscriptions = {}
      projector_names.split(",").map do |projector_name|
        projector = projector_name.strip.camelize.constantize.new
        projector.handled_event_names.each do |event_name|
          subscriptions[event_name.to_s] ||= []
          if !subscriptions[event_name.to_s].include?(projector)
            subscriptions[event_name.to_s].push(projector)
          end
        end
      end
      subscriptions
    end

    def projectors_subscriptions_with_regexp(projector_names)
      subscriptions = []
      projector_names.split(",").map do |projector_name|
        projector = projector_name.strip.camelize.constantize.new
        subscriptions.push(projector) if projector.handled_event_expressions.size > 0
      end
      subscriptions
    end
  end
end
