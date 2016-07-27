  module Happn
  class SubscriptionRepository

    def initialize(logger)
      @subscriptions_by_name       = {}
      @subscriptions_by_kind       = {}
      @subscriptions_by_expression = {}
      @subscriptions_for_all       = []
      @logger                      = logger
    end

    def register(query, projector, &block)
      puts "coucou"
      puts query.class
      if query.instance_of? Regexp
        register_expression(query, projector, &block)
      elsif query.instance_of? String
        register_by_name(query, projector, &block)
      elsif query == :all
        register_for_all(projector, &block)
      elsif query.instance_of?(Hash) && query.key?(:kind)
        register_by_kind(query[:kind], projector, &block)
      else
        throw new StandardError.new("#{query.class} is not handled as a valid query")
      end
    end

    def find_subscriptions_for(event)
      event_name    = event.fetch("meta").fetch("name")
      subscriptions = []
      subscriptions += @subscriptions_by_name[event_name] || []
      subscriptions += @subscriptions_by_kind[event.fetch("meta").fetch("kind")] || []
      subscriptions += find_subscription_by_expression(event_name)
      subscriptions += @subscriptions_for_all
      subscriptions
    end

    private

    def find_subscription_by_expression(event_name)
      @subscriptions_by_expression.select { | expression, subscription | event_name.match(expression) }.values
    end

    def register_by_expression(expression, projector, &block)
      @subscriptions_by_expression[expression] ||= []
      @subscriptions_by_expression[expression].push(Subscription.new(projector, &block))
      @logger.info("Register Event Handler from projector '#{projector.class}' for expression : '#{expression}'.")
    end

    def register_by_name(name, projector, &block)
      @subscriptions_by_name[name] ||= []
      @subscriptions_by_name[name].push(Subscription.new(projector, &block))
      @logger.info("Register Event Handler from projector '#{projector.class}' for name : '#{name}'.")
    end

    def register_by_kind(kind, projector, &block)
      @subscriptions_by_kind[kind] ||= []
      @subscriptions_by_kind[kind].push(Subscription.new(projector, &block))
      @logger.info("Register Event Handler from projector '#{projector.class}' for kind : '#{kind}'.")
    end


    def register_for_all(projector, &block)
      @subscriptions_for_all.push(Subscription.new(projector, &block))
      @logger.info("Register Event Handler from projector '#{projector.class}' for all events.")
    end
  end
end
