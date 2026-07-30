module Happn
  class Configuration
    attr_accessor :logger,
                  :rabbitmq_host,
                  :rabbitmq_port,
                  :rabbitmq_management_port,
                  :rabbitmq_management_scheme,
                  :rabbitmq_user,
                  :rabbitmq_password,
                  :rabbitmq_queue_name,
                  :rabbitmq_exchange_name,
                  :rabbitmq_exchange_durable,
                  :rabbitmq_queue_mode,
                  :rabbitmq_prefetch_size,
                  :projector_classes,
                  :bunny_options,
                  :management_options,
                  :on_error
  end
end
