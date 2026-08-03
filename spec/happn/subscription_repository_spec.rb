RSpec.describe Happn::SubscriptionRepository do

  let(:logger)    { instance_double(Logger, info: nil) }
  let(:projector) { Happn::SpecProjectors::CatchAll.new(logger, described_class.new(logger)) }

  subject(:repository) { described_class.new(logger) }

  def register(emitter: :all, kind: :all, name: :all, status: :all, &block)
    repository.register(Happn::Query.new(emitter, kind, name, status), projector, &(block || proc { |event| event }))
  end

  describe "#register" do
    it "stores the subscription" do
      register(name: "create country")

      expect(repository.find_all.size).to eq(1)
    end

    it "builds a subscription out of the query, the projector and the block" do
      register(name: "create country") { |event| "handled #{event}" }

      subscription = repository.find_all.first
      expect(subscription).to be_a(Happn::Subscription)
      expect(subscription.projector).to be(projector)
      expect(subscription.handler.call("42")).to eq("handled 42")
    end

    it "logs the registration" do
      expect(logger).to receive(:info).with("Subscribe projector 'Happn::SpecProjectors::CatchAll' to query : [new][MyApplication][entity_change][create country]")

      register(emitter: "MyApplication", kind: "entity_change", name: "create country", status: :new)
    end

    it "keeps several subscriptions registered on the very same query" do
      register(name: "create country")
      register(name: "create country")

      expect(repository.find_all.size).to eq(2)
    end
  end

  describe "#find_all" do
    it "is empty when nothing was registered" do
      expect(repository.find_all).to eq([])
    end

    it "flattens the subscriptions of every branch of the index" do
      register(status: :new, emitter: "A", kind: "k1", name: "n1")
      register(status: :replayed, emitter: "B", kind: "k2", name: "n2")
      register(status: :new, emitter: "A", kind: "k1", name: "n3")

      expect(repository.find_all.map { |subscription| subscription.query.name }).to contain_exactly("n1", "n2", "n3")
    end

    it "returns Subscription instances" do
      register

      expect(repository.find_all).to all(be_a(Happn::Subscription))
    end
  end

  describe "#find_subscriptions_for" do
    let(:event) { stub_event(emitter: "MyApplication", kind: "entity_change", name: "create country", status: "new") }

    it "matches a subscription describing the event exactly" do
      register(emitter: "MyApplication", kind: "entity_change", name: "create country", status: :new)

      expect(repository.find_subscriptions_for(event).size).to eq(1)
    end

    it "matches a subscription made of wildcards only" do
      register

      expect(repository.find_subscriptions_for(event).size).to eq(1)
    end

    it "matches a subscription registered with nil attributes" do
      register(emitter: nil, kind: nil, name: nil, status: nil)

      expect(repository.find_subscriptions_for(event).size).to eq(1)
    end

    it "matches a subscription mixing wildcards and exact attributes" do
      register(name: "create country", status: :new)

      expect(repository.find_subscriptions_for(event).size).to eq(1)
    end

    ["emitter", "kind", "name", "status"].each do |attribute|
      it "ignores a subscription whose #{attribute} differs" do
        register(**{ attribute.to_sym => "something else" })

        expect(repository.find_subscriptions_for(event)).to be_empty
      end
    end

    it "is empty when nothing was registered" do
      expect(repository.find_subscriptions_for(event)).to eq([])
    end

    it "returns every matching subscription" do
      register
      register(name: "create country")
      register(emitter: "MyApplication", kind: "entity_change", name: "create country", status: :new)
      register(name: "delete country")

      expect(repository.find_subscriptions_for(event).size).to eq(3)
    end

    it "returns the several handlers registered on one same query" do
      register(name: "create country")
      register(name: "create country")

      expect(repository.find_subscriptions_for(event).size).to eq(2)
    end

    it "matches an event whose status is a Symbol" do
      register(status: :new)

      expect(repository.find_subscriptions_for(stub_event(status: :new)).size).to eq(1)
    end

    it "does not leak subscriptions of another event" do
      register(name: "delete country")

      expect(repository.find_subscriptions_for(event)).to be_empty
    end

    "emitter", "kind", "name", "status"].each do |attribute|
      it "matches a wildcard subscription once for an event whose #{attribute} is literally 'all'" do
        register

        expect(repository.find_subscriptions_for(stub_event(**{ attribute.to_sym => "all" })).size).to eq(1)
      end
    end

    it "matches a wildcard subscription once for an event made of 'all' attributes" do
      register

      event = stub_event(emitter: "all", kind: "all", name: "all", status: "all")
      expect(repository.find_subscriptions_for(event).size).to eq(1)
    end

    it "still runs every distinct handler of an event made of 'all' attributes" do
      register
      register
      register(name: "delete country")

      event = stub_event(emitter: "all", kind: "all", name: "all", status: "all")
      expect(repository.find_subscriptions_for(event).size).to eq(2)
    end
  end
end
