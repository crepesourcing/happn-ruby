module Happn
  class Projector

    def initialize(logger, subscription_repository)
      @logger                  = logger
      @subscription_repository = subscription_repository
    end

    def define_handlers
    end

    def on(query, &block)
      @subscription_repository.register(normalize(query), self, &block)
    end

    private

    def normalize(query)
      if query == :all
        Query.for_all
      else
        emitter = query[:emitter] || :all
        kind    = query[:kind]    || :all
        name    = query[:name]    || :all
        Query.new(emitter, kind, name)
      end
    end
  end
end
