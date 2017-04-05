module Happn
  class Configuration
    include ActiveSupport::Configurable
    config_accessor :logger
    config_accessor :rabbitmq_host
    config_accessor :rabbitmq_port
    config_accessor :rabbitmq_management_port
    config_accessor :rabbitmq_user
    config_accessor :rabbitmq_password
    config_accessor :rabbitmq_queue_name
    config_accessor :rabbitmq_exchange_name
    config_accessor :rabbitmq_exchange_durable
    config_accessor :rabbitmq_queue_mode
    config_accessor :rabbitmq_prefetch_size
    config_accessor :projector_classes
    config_accessor :on_error
  end
end
