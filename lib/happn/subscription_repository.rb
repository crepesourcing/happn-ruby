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
      status       = query.status
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
      meta                    = event.fetch("meta")
      possible_event_statuses = ["all", meta.fetch("status")]
      possible_event_names    = ["all", meta.fetch("name")]
      possible_event_kinds    = ["all", meta.fetch("kind")]
      possible_event_emitters = ["all", meta.fetch("emitter")]
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
