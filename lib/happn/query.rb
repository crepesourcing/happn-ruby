module Happn
  class Query

    attr_reader :emitter, :kind, :name, :run_on_replayed_events

    def initialize(emitter, kind, name, run_on_replayed_events)
      raise "'Dot' is not a valid character" if emitter.to_s.include?(".") || kind.to_s.include?(".") || name.to_s.include?(".")

      @emitter                = emitter
      @kind                   = kind
      @name                   = name
      @run_on_replayed_events = run_on_replayed_events
    end

    def to_routing_key
      "#{to_expression(@emitter)}.#{to_expression(@kind)}.#{to_expression(@name)}"
    end

    private

    def to_expression(query_expression)
      query_expression == :all ? "*" : query_expression
    end

  end
end
