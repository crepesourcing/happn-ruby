module Happn
  class Configuration
    include ActiveSupport::Configurable
    config_accessor :logger
    config_accessor :max_retries
    config_accessor :rabbitmq_host
    config_accessor :rabbitmq_port
    config_accessor :rabbitmq_user
    config_accessor :rabbitmq_password
    config_accessor :rabbitmq_queue_name
    config_accessor :rabbitmq_exchange_name
    config_accessor :rabbitmq_exchange_durable
    config_accessor :projector_classes
  end
end
