require_relative "happn/event"
require_relative "happn/query"
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
    Happn::register(@configuration.projector_classes, subscription_repository)
    @event_consumer         = EventConsumer.new(@logger, @configuration, subscription_repository)
  end

  def self.start
    @event_consumer.start
  end

  def self.create_queue_only
    Happn.init
    @event_consumer.wait_until_connected
  end

  configure do |config|
    config.logger                     = nil
    config.rabbitmq_host              = "localhost"
    config.rabbitmq_port              = "5672"
    config.rabbitmq_management_scheme = "http"
    config.rabbitmq_management_port   = "15672"
    config.rabbitmq_user              = ""
    config.rabbitmq_password          = ""
    config.rabbitmq_queue_name        = "happn-queue"
    config.rabbitmq_exchange_name     = "events"
    config.rabbitmq_exchange_durable  = true
    config.rabbitmq_queue_mode        = nil
    config.rabbitmq_prefetch_size     = 10
    config.projector_classes          = []
    config.on_error                   = nil
    config.bunny_options              = {}
    config.on_error                   = nil
  end

  private

  def self.register(projector_classes, subscription_repository)
    @logger.info("#{projector_classes.size} projector are going to be registered...")
    projector_classes.each do | projector_class |
      projector = projector_class.new(@logger, subscription_repository)
      projector.define_handlers
      @logger.info("Projector '#{projector_class}' registered")
    end
  end

end
