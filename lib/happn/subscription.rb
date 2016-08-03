module Happn
  class Subscription

    attr_reader :handler, :projector, :query

    def initialize(query, projector, &handler)
      @query           = query
      @projector       = projector
      @handler         = handler
    end
  end
end
