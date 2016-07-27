module Happn
  class Projector

    def initialize(logger, subscription_repository)
      @logger                  = logger
      @subscription_repository = subscription_repository
    end

    def define_handlers
    end

    def on(query, &block)
      @subscription_repository.register(query, self, &block)
    end
  end
end
