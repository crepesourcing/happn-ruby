module Happn
  class Subscription

    attr_reader :handler, :projector

    def initialize(projector, &handler)
      @projector = projector
      @handler   = handler
    end
  end
end
