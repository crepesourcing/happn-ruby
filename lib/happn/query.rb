module Happn
  class Query

    attr_reader :emitter, :kind, :name

    def initialize(emitter, kind, name)
      raise "'Dot' is not a valid character" if emitter.to_s.include?(".") || kind.to_s.include?(".") || name.to_s.include?(".")

      @emitter = emitter
      @kind    = kind
      @name    = name
    end

    def self.for_all
      Query.new(:all, :all, :all)
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
