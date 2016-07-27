require_relative "happn/version"
require_relative "happn/configuration"
require_relative "happn/event_consumer"
require_relative "happn/subscription"
require_relative "happn/subscription_repository"
require_relative "happn/projector"
require "logger"

module Happn
  def self.configure
    yield @configuration ||= Happn::Configuration.new
  end

  def self.config
    @configuration
  end

  def self.logger
    @logger
  end

  def self.init
    @logger                 = @configuration.logger || Logger.new(STDOUT)
    subscription_repository = SubscriptionRepository.new(@logger)
    projectors              = Happn::register(@configuration.projector_names, subscription_repository)
    @event_consumer         = EventConsumer.new(@logger, @configuration, subscription_repository)
  end

  def self.start
    @event_consumer.start
  end

  configure do |config|
    config.logger                     = nil
    config.rabbitmq_host              = "localhost"
    config.rabbitmq_port              = "5672"
    config.rabbitmq_user              = ""
    config.rabbitmq_password          = ""
    config.rabbitmq_exchange_name     = "events"
    config.rabbitmq_exchange_type     = "fanout"
    config.rabbitmq_exchange_durable  = true
    config.max_retries                = 5
  end

  private

  def self.register(projector_names, subscription_repository)
    projector_names.split(",").map do | projector_name |
      projector = projector_name.strip.camelize.constantize.new(@logger, subscription_repository)
      projector.define_handlers
    end
  end

end
