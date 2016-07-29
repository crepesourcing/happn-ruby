  module Happn
  class SubscriptionRepository

    def initialize(logger)
      @subscriptions = {}
      @logger        = logger
    end

    def register(query, projector, &block)
      subscription = Subscription.new(query, projector, &block)
      emitter      = query.emitter
      kind         = query.kind
      name         = query.name
      @subscriptions[emitter]              ||= {}
      @subscriptions[emitter][kind]        ||= {}
      @subscriptions[emitter][kind][name]  ||= []
      @subscriptions[emitter][kind][name].push(subscription)
      @logger.info("Subscribe projector '#{projector.class}' to query : [#{emitter}][#{kind}][#{name}]")
    end

    def find_all
      flatten(@subscriptions)
    end

    def find_subscriptions_for(event)
      meta                    = event.fetch("meta")
      possible_event_names    = [:all, meta.fetch("name")]
      possible_event_kinds    = [:all, meta.fetch("kind")]
      possible_event_emitters = [:all, meta.fetch("emitter")]
      subscriptions           = []

      possible_event_emitters.each do | emitter |
        possible_event_kinds.each do | kind |
          possible_event_names.each do | name |
            subscriptions += @subscriptions.dig(emitter, kind, name) || []
          end
        end
      end

      if meta[:replayed]
        subscriptions = subscriptions.select { | subscription | subscription.query.run_on_replayed_events }
      end
      subscriptions
    end

    private

    def flatten(item)
      if item.instance_of?(Hash)
        item.values.inject([]) do | result, value |
          result += flatten(value)
        end
      else
        item
      end
    end
  end
end
