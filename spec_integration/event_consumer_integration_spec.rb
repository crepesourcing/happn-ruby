require_relative "integration_helper"

RSpec.describe Happn::EventConsumer do

  let(:queue_name)    { "happn-integration-#{SecureRandom.hex(4)}" }
  let(:exchange_name) { "happn-integration-#{SecureRandom.hex(4)}" }

  after { cleanup_queue(queue_name, exchange_name) }

  def build_consumer(matcher:)
    Happn::IntegrationSpecProjectors::Recording.reset!
    Happn::IntegrationSpecProjectors::Recording.matcher = matcher

    configuration = Happn::Configuration.new.tap do |config|
      config.logger                     = silent_logger
      config.rabbitmq_host              = rabbitmq_host
      config.rabbitmq_port              = rabbitmq_port
      config.rabbitmq_management_scheme = "http"
      config.rabbitmq_management_port   = rabbitmq_management_port
      config.rabbitmq_user              = rabbitmq_user
      config.rabbitmq_password          = rabbitmq_password
      config.rabbitmq_queue_name        = queue_name
      config.rabbitmq_exchange_name     = exchange_name
      config.rabbitmq_exchange_durable  = false
      config.rabbitmq_prefetch_size     = 10
      config.bunny_options              = {}
      config.management_options         = {}
    end

    repository = Happn::SubscriptionRepository.new(silent_logger)
    projector  = Happn::IntegrationSpecProjectors::Recording.new(silent_logger, repository)
    projector.define_handlers

    [described_class.new(silent_logger, configuration, repository), projector]
  end

  def consume_in_background(consumer)
    thread = Thread.new { consumer.start }
    yield
  ensure
    thread.kill
    thread.join(2)
  end

  it "declares the configured queue" do
    consumer, = build_consumer(matcher: { name: "create country" })

    consumer.wait_until_connected

    expect { queue_message_count(queue_name) }.not_to raise_error
  end

  it "binds the exchange to the queue for the registered routing key" do
    consumer, = build_consumer(matcher: { name: "create country", status: :new })

    consumer.wait_until_connected

    bindings = management_client.list_queue_bindings("/", queue_name).map(&:routing_key)
    expect(bindings).to include("new.*.*.create country")
  end

  it "removes bindings that are no longer registered when it reconnects" do
    first_consumer, = build_consumer(matcher: { name: "create country" })
    first_consumer.wait_until_connected

    second_consumer, = build_consumer(matcher: { name: "delete country" })
    second_consumer.wait_until_connected

    bindings = management_client.list_queue_bindings("/", queue_name).map(&:routing_key)
    expect(bindings).to include("*.*.*.delete country")
    expect(bindings).not_to include("*.*.*.create country")
  end

  it "delivers a matching message to its handler and acknowledges it" do
    consumer, projector = build_consumer(matcher: { name: "create country", status: :new })
    consumer.wait_until_connected

    publish(exchange_name, "new.MyApplication.entity_change.create country", build_event_payload)

    consume_in_background(consumer) do
      wait_until { projector.consumed.any? }
      wait_until { queue_message_count(queue_name).zero? }
    end

    expect(projector.consumed.map(&:name)).to eq(["create country"])
  end

  it "drops a message whose routing key matches no registered subscription" do
    consumer, projector = build_consumer(matcher: { name: "create country" })
    consumer.wait_until_connected

    publish(exchange_name, "new.MyApplication.entity_change.delete country",
            build_event_payload(meta: { "name" => "delete country" }))

    expect(queue_message_count(queue_name)).to eq(0)
    expect(projector.consumed).to be_empty
  end
end
