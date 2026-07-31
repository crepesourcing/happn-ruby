require "json"
require "logger"

module Happn
  # Small builders shared by all specs. They keep the examples focused on the
  # behaviour under test instead of on the shape of a CREPE event payload.
  module SpecHelpers

    DEFAULT_META = {
      "id"        => "3d0d7c9e-4f0f-4d0a-9c9a-2a1b0c3d4e5f",
      "name"      => "create country",
      "kind"      => "entity_change",
      "status"    => "new",
      "emitter"   => "MyApplication",
      "timestamp" => "2026-07-31T10:15:30+02:00"
    }.freeze

    DEFAULT_DATA = {
      "changes"          => {},
      "associations"     => {},
      "user_metadata"    => {},
      "request_metadata" => {}
    }.freeze

    def build_event(meta: {}, data: {})
      Happn::Event.new("meta" => DEFAULT_META.merge(meta),
                       "data" => DEFAULT_DATA.merge(data))
    end

    def build_event_payload(meta: {}, data: {})
      JSON.generate("meta" => DEFAULT_META.merge(meta),
                    "data" => DEFAULT_DATA.merge(data))
    end

    def silent_logger
      Logger.new(IO::NULL)
    end

    # `find_subscriptions_for` only reads the four routing attributes of an
    # event, so a lightweight stand-in keeps those examples readable.
    def stub_event(emitter: "MyApplication", kind: "entity_change", name: "create country", status: "new")
      instance_double(Happn::Event, emitter: emitter, kind: kind, name: name, status: status)
    end
  end
end
