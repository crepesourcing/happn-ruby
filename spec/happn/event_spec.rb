RSpec.describe Happn::Event do

  describe "#initialize" do
    it "requires a 'meta' entry" do
      expect { described_class.new("data" => {}) }.to raise_error(KeyError)
    end

    it "requires a 'data' entry" do
      expect { described_class.new("meta" => {}) }.to raise_error(KeyError)
    end

    it "underscores and symbolizes the keys of 'meta'" do
      event = described_class.new("meta" => { "eventName" => "create country" }, "data" => {})

      expect(event.name).to be_nil
      expect(event.instance_variable_get(:@meta)).to eq(event_name: "create country")
    end

    it "underscores and symbolizes the keys of 'data'" do
      event = described_class.new("meta" => {}, "data" => { "userMetadata" => { "userId" => 42 } })

      expect(event.data).to eq(user_metadata: { user_id: 42 })
    end

    it "underscores keys nested inside arrays" do
      event = described_class.new("meta" => {},
                                  "data" => { "lineItems" => [{ "productName" => "bunny" }, { "productName" => "carrot" }] })

      expect(event.data).to eq(line_items: [{ product_name: "bunny" }, { product_name: "carrot" }])
    end

    it "leaves scalar values untouched" do
      event = described_class.new("meta" => {}, "data" => { "count" => 3, "ratio" => 1.5, "enabled" => true, "missing" => nil })

      expect(event.data).to eq(count: 3, ratio: 1.5, enabled: true, missing: nil)
    end

    it "splits consecutive capitals of an acronym" do
      event = described_class.new("meta" => {}, "data" => { "HTTPResponseCode" => 200 })

      expect(event.data).to eq(http_response_code: 200)
    end

    it "turns dashes into underscores" do
      event = described_class.new("meta" => {}, "data" => { "user-id" => 42 })

      expect(event.data).to eq(user_id: 42)
    end

    it "turns namespace separators into slashes" do
      event = described_class.new("meta" => {}, "data" => { "Happn::Event" => "value" })

      expect(event.data).to eq(:"happn/event" => "value")
    end

    it "keeps an already underscored key as is" do
      event = described_class.new("meta" => {}, "data" => { "request_metadata" => { "ip" => "127.0.0.1" } })

      expect(event.data).to eq(request_metadata: { ip: "127.0.0.1" })
    end
  end

  describe "the 'meta' accessors" do
    subject(:event) { build_event }

    it "exposes the id" do
      expect(event.id).to eq(Happn::SpecHelpers::DEFAULT_META["id"])
    end

    it "exposes the name" do
      expect(event.name).to eq("create country")
    end

    it "exposes the kind" do
      expect(event.kind).to eq("entity_change")
    end

    it "exposes the status" do
      expect(event.status).to eq("new")
    end

    it "exposes the emitter" do
      expect(event.emitter).to eq("MyApplication")
    end

    it "returns nil for a 'meta' entry that was not emitted" do
      expect(build_event(meta: { "id" => nil }).id).to be_nil
    end
  end

  describe "#timestamp" do
    it "parses the raw timestamp into a DateTime" do
      event = build_event(meta: { "timestamp" => "2026-07-31T10:15:30+02:00" })

      expect(event.timestamp).to eq(DateTime.new(2026, 7, 31, 10, 15, 30, "+02:00"))
    end

    it "keeps the offset carried by the payload" do
      event = build_event(meta: { "timestamp" => "2026-07-31T10:15:30+02:00" })

      expect(event.timestamp.zone).to eq("+02:00")
    end

    it "raises when the timestamp cannot be parsed" do
      expect { build_event(meta: { "timestamp" => "not a date" }).timestamp }.to raise_error(Date::Error)
    end
  end

  describe "the 'data' accessors" do
    it "exposes the whole data payload" do
      event = build_event(data: { "changes" => { "name" => [nil, "Belgium"] } })

      expect(event.data[:changes]).to eq(name: [nil, "Belgium"])
    end

    it "exposes the user metadata" do
      event = build_event(data: { "user_metadata" => { "userId" => 42 } })

      expect(event.user_metadata).to eq(user_id: 42)
    end

    it "exposes the request metadata" do
      event = build_event(data: { "request_metadata" => { "controllerName" => "countries" } })

      expect(event.request_metadata).to eq(controller_name: "countries")
    end

    it "exposes the associations" do
      event = build_event(data: { "associations" => { "countryId" => 1 } })

      expect(event.associations).to eq(country_id: 1)
    end

    it "returns nil when the payload carries no changes at all" do
      event = described_class.new("meta" => {}, "data" => {})

      expect(event.changes).to be_nil
    end
  end

  describe "#changes=" do
    it "replaces the whole set of changes" do
      event = build_event(data: { "changes" => { "name" => [nil, "Belgium"] } })

      event.changes = { code: ["BE", "FR"] }

      expect(event.changes).to eq(code: ["BE", "FR"])
    end
  end

  describe "#add_change" do
    subject(:event) { build_event(data: { "changes" => {} }) }

    it "records the value as the 'after' half of the change" do
      event.add_change(:name, "Belgium")

      expect(event.changes).to eq(name: [nil, "Belgium"])
    end

    it "symbolizes a name given as a String" do
      event.add_change("name", "Belgium")

      expect(event.changes).to eq(name: [nil, "Belgium"])
    end

    it "normalizes an empty String into nil" do
      event.add_change(:name, "")

      expect(event.changes).to eq(name: [nil, nil])
    end

    it "keeps a false value" do
      event.add_change(:enabled, false)

      expect(event.changes).to eq(enabled: [nil, false])
    end

    it "overwrites a change that was already there" do
      event = build_event(data: { "changes" => { "name" => ["France", "Belgium"] } })

      event.add_change(:name, "Italy")

      expect(event.changes).to eq(name: [nil, "Italy"])
    end
  end

  describe "#change_after" do
    subject(:event) { build_event(data: { "changes" => { "name" => ["France", "Belgium"] } }) }

    it "returns the new value" do
      expect(event.change_after(:name)).to eq("Belgium")
    end

    it "accepts the attribute name as a String" do
      expect(event.change_after("name")).to eq("Belgium")
    end

    it "returns nil for an attribute that did not change" do
      expect(event.change_after(:code)).to be_nil
    end
  end

  describe "#change_before" do
    subject(:event) { build_event(data: { "changes" => { "name" => ["France", "Belgium"] } }) }

    it "returns the previous value" do
      expect(event.change_before(:name)).to eq("France")
    end

    it "accepts the attribute name as a String" do
      expect(event.change_before("name")).to eq("France")
    end

    it "returns nil for an attribute that did not change" do
      expect(event.change_before(:code)).to be_nil
    end
  end

  describe "#has_change?" do
    subject(:event) { build_event(data: { "changes" => { "name" => ["France", "Belgium"] } }) }

    it "is true for a changed attribute" do
      expect(event.has_change?(:name)).to be(true)
    end

    it "is false for an untouched attribute" do
      expect(event.has_change?(:code)).to be(false)
    end

    # Unlike `change_after` and `change_before`, this method does not call
    # `to_sym` on its argument, so a String never matches. Documented here so a
    # future fix breaks this example on purpose.
    it "is false for a changed attribute given as a String" do
      expect(event.has_change?("name")).to be(false)
    end
  end

  describe "#delete_change" do
    subject(:event) { build_event(data: { "changes" => { "name" => ["France", "Belgium"] } }) }

    it "removes the change and returns it" do
      expect(event.delete_change(:name)).to eq(["France", "Belgium"])
      expect(event.changes).to be_empty
    end

    it "returns nil for an attribute that did not change" do
      expect(event.delete_change(:code)).to be_nil
    end

    # Same String/Symbol asymmetry as `has_change?`.
    it "does not remove anything when the name is given as a String" do
      event.delete_change("name")

      expect(event.changes).to eq(name: ["France", "Belgium"])
    end
  end
end
