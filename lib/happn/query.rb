module Happn
  class Query

    attr_reader :emitter, :kind, :name, :status

    def initialize(emitter, kind, name, status)
      emitter = emitter.to_s
      kind    = kind.to_s
      name    = name.to_s
      status  = status.to_s

      if emitter.include?(".") || kind.include?(".") || name.include?(".") || status.include?(".")
        raise "'Dot' is not a valid character"
      end

      @emitter = emitter
      @kind    = kind
      @name    = name
      @status  = status
    end

    def to_routing_key
      "#{to_expression(@status)}.#{to_expression(@emitter)}.#{to_expression(@kind)}.#{to_expression(@name)}"
    end

    private

    def to_expression(query_expression)
      query_expression == "all" ? "*" : query_expression
    end
  end
end
