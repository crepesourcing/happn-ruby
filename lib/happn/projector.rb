module Happn
  class Projector

    def initialize(logger, subscription_repository)
      @logger                  = logger
      @subscription_repository = subscription_repository
    end

    def define_handlers
    end

    def on(emitter: :all, kind: :all, name: :all, replay: true, &block)
      query = Query.new(emitter, kind, name, replay)
      @subscription_repository.register(query, self, &block)
    end
  end
end
