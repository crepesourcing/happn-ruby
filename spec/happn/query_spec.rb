RSpec.describe Happn::Query do

  describe "#initialize" do
    it "exposes the four routing attributes" do
      query = described_class.new("MyApplication", "entity_change", "create country", :new)

      expect(query.emitter).to eq("MyApplication")
      expect(query.kind).to eq("entity_change")
      expect(query.name).to eq("create country")
      expect(query.status).to eq(:new)
    end

    # A dot is the separator of an AMQP routing key: letting one through would
    # silently shift every other attribute of the key.
    ["emitter", "kind", "name", "status"].each_with_index do |attribute, index|
      it "rejects a dot inside the #{attribute}" do
        arguments        = [:all, :all, :all, :all]
        arguments[index] = "with.a.dot"

        expect { described_class.new(*arguments) }.to raise_error("'Dot' is not a valid character")
      end
    end

    it "rejects a dot carried by a Symbol" do
      expect { described_class.new(:"my.emitter", :all, :all, :all) }.to raise_error("'Dot' is not a valid character")
    end

    it "accepts attributes without any dot" do
      expect { described_class.new("MyApplication", "entity_change", "create country", :new) }.not_to raise_error
    end

    it "accepts nil attributes" do
      expect { described_class.new(nil, nil, nil, nil) }.not_to raise_error
    end
  end

  describe "#to_routing_key" do
    it "joins the attributes as status.emitter.kind.name" do
      query = described_class.new("MyApplication", "entity_change", "create country", "new")

      expect(query.to_routing_key).to eq("new.MyApplication.entity_change.create country")
    end

    it "turns :all into the AMQP single-word wildcard" do
      query = described_class.new(:all, :all, :all, :all)

      expect(query.to_routing_key).to eq("*.*.*.*")
    end

    it "only replaces the attributes set to :all" do
      query = described_class.new(:all, "entity_change", :all, "new")

      expect(query.to_routing_key).to eq("new.*.entity_change.*")
    end

    it "renders Symbol attributes" do
      query = described_class.new(:my_application, :entity_change, :create_country, :new)

      expect(query.to_routing_key).to eq("new.my_application.entity_change.create_country")
    end

    # `nil` is not turned into a wildcard: only `:all` is. A query built with
    # nil attributes therefore binds to an empty routing key.
    it "renders nil attributes as empty words" do
      query = described_class.new(nil, nil, nil, nil)

      expect(query.to_routing_key).to eq("...")
    end
  end
end
