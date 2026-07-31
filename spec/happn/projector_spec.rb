RSpec.describe Happn::Projector do

  let(:logger)     { instance_double(Logger, info: nil) }
  let(:repository) { Happn::SubscriptionRepository.new(logger) }

  subject(:projector) { described_class.new(logger, repository) }

  describe "#define_handlers" do
    it "registers nothing by default" do
      Happn::SpecProjectors::Silent.new(logger, repository).define_handlers

      expect(repository.find_all).to be_empty
    end
  end

  describe "#on" do
    it "registers a subscription in the repository" do
      projector.on(emitter: "MyApplication", kind: "entity_change", name: "create country", status: :new) { |event| event }

      expect(repository.find_all.size).to eq(1)
    end

    it "builds the query out of the given attributes" do
      projector.on(emitter: "MyApplication", kind: "entity_change", name: "create country", status: :new) { |event| event }

      query = repository.find_all.first.query
      expect(query.emitter).to eq("MyApplication")
      expect(query.kind).to eq("entity_change")
      expect(query.name).to eq("create country")
      expect(query.status).to eq(:new)
    end

    it "defaults every unspecified attribute to :all" do
      projector.on { |event| event }

      query = repository.find_all.first.query
      expect([query.emitter, query.kind, query.name, query.status]).to eq([:all, :all, :all, :all])
    end

    it "keeps the other attributes at :all when only one is given" do
      projector.on(name: "create country") { |event| event }

      query = repository.find_all.first.query
      expect(query.to_routing_key).to eq("*.*.*.create country")
    end

    it "treats an attribute explicitly set to nil as :all" do
      projector.on(emitter: nil, name: "create country") { |event| event }

      query = repository.find_all.first.query
      expect(query.emitter).to eq(:all)
      expect(query.to_routing_key).to eq("*.*.*.create country")
    end

    it "subscribes the projector itself" do
      projector.on { |event| event }

      expect(repository.find_all.first.projector).to be(projector)
    end

    it "passes the block along as the handler" do
      projector.on { |event| "handled #{event}" }

      expect(repository.find_all.first.handler.call("42")).to eq("handled 42")
    end

    it "registers one subscription per call" do
      projector.on(name: "create country") { |event| event }
      projector.on(name: "delete country") { |event| event }

      expect(repository.find_all.size).to eq(2)
    end

    it "propagates the validation error of the query" do
      expect { projector.on(name: "create.country") { |event| event } }.to raise_error("'Dot' is not a valid character")
    end
  end

  describe "a projector subclass" do
    it "registers its handlers when 'define_handlers' is called" do
      Happn::SpecProjectors::Recording.new(logger, repository).define_handlers

      expect(repository.find_all.map { |subscription| subscription.query.to_routing_key }).to eq(["*.*.*.create country"])
    end

    it "registers nothing until 'define_handlers' is called" do
      Happn::SpecProjectors::Recording.new(logger, repository)

      expect(repository.find_all).to be_empty
    end
  end
end
