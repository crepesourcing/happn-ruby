RSpec.describe Happn::Subscription do

  let(:query)     { Happn::Query.new(:all, :all, "create country", :new) }
  let(:projector) { Happn::SpecProjectors::CatchAll.new(silent_logger, Happn::SubscriptionRepository.new(silent_logger)) }

  subject(:subscription) do
    described_class.new(query, projector) { |event| "handled #{event}" }
  end

  it "exposes the query" do
    expect(subscription.query).to be(query)
  end

  it "exposes the projector" do
    expect(subscription.projector).to be(projector)
  end

  it "exposes the handler as a Proc" do
    expect(subscription.handler).to be_a(Proc)
  end

  it "keeps the handler callable" do
    expect(subscription.handler.call("42")).to eq("handled 42")
  end

  it "accepts being built without a handler" do
    expect(described_class.new(query, projector).handler).to be_nil
  end
end
