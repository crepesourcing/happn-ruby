module Happn
  class SubscriptionRepository

    def initialize(logger)
      @subscriptions = {}
      @logger        = logger
    end

    def register(query, projector, &block)
      subscription = Subscription.new(query, projector, &block)
      emitter      = query.emitter.to_s
      kind         = query.kind.to_s
      name         = query.name.to_s
      status       = query.status.to_s
      @subscriptions[status]                       ||= {}
      @subscriptions[status][emitter]              ||= {}
      @subscriptions[status][emitter][kind]        ||= {}
      @subscriptions[status][emitter][kind][name]  ||= []
      @subscriptions[status][emitter][kind][name].push(subscription)
      @logger.info("Subscribe projector '#{projector.class}' to query : [#{status}][#{emitter}][#{kind}][#{name}]")
    end

    def find_all
      flatten(@subscriptions)
    end

    def find_subscriptions_for(event)
      possible_event_statuses = ["all", event.status.to_s]
      possible_event_emitters = ["all", event.emitter.to_s]
      possible_event_names    = ["all", event.name.to_s]
      possible_event_kinds    = ["all", event.kind.to_s]
      subscriptions           = []
      possible_event_statuses.each do | status |
        possible_event_emitters.each do | emitter |
          possible_event_kinds.each do | kind |
            possible_event_names.each do | name |
              subscriptions += @subscriptions.dig(status, emitter, kind, name) || []
            end
          end
        end
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
