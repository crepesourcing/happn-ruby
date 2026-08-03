RSpec.describe Happn::EventConsumer do

  let(:logger)     { instance_double(Logger, info: nil, warn: nil, error: nil, fatal: nil) }
  let(:connection) { instance_double(Bunny::Session, start: nil) }
  let(:channel) do
    instance_double(Bunny::Channel, on_uncaught_exception: nil, basic_qos: nil, acknowledge: nil, reject: nil)
  end
  let(:queue)      { instance_double(Bunny::Queue, name: "happn-queue", bind: nil, unbind: nil) }
  let(:exchange)   { instance_double(Bunny::Exchange) }
  let(:management) { instance_double(RabbitMQ::HTTP::Client) }
  let(:repository) { Happn::SubscriptionRepository.new(silent_logger) }

  let(:configuration) do
    Happn::Configuration.new.tap do |config|
      config.rabbitmq_host              = "rabbit.example.org"
      config.rabbitmq_port              = 5672
      config.rabbitmq_user              = "guest"
      config.rabbitmq_password          = "secret"
      config.rabbitmq_management_scheme = "http"
      config.rabbitmq_management_port   = 15672
      config.rabbitmq_queue_name        = "happn-queue"
      config.rabbitmq_exchange_name     = "events"
      config.rabbitmq_exchange_durable  = true
      config.rabbitmq_prefetch_size     = 10
      config.bunny_options              = {}
      config.management_options         = {}
    end
  end

  subject(:consumer) { described_class.new(logger, configuration, repository) }

  before do
    allow(Bunny).to receive(:new).and_return(connection)
    allow(RabbitMQ::HTTP::Client).to receive(:new).and_return(management)
    allow(connection).to receive(:create_channel).and_return(channel)
    allow(channel).to receive(:queue).and_return(queue)
    allow(channel).to receive(:topic).and_return(exchange)
    allow(management).to receive(:list_queue_bindings).and_return([])
  end

  def binding_double(routing_key, source: "events")
    double("binding", routing_key: routing_key, source: source)
  end

  describe "#initialize" do
    it "opens the Bunny connection with the configured broker" do
      expect(Bunny).to receive(:new).with(hash_including(host: "rabbit.example.org",
                                                        port: 5672,
                                                        user: "guest",
                                                        password: "secret"))

      consumer
    end

    it "lets Bunny recover the connection automatically" do
      expect(Bunny).to receive(:new).with(hash_including(automatically_recover: true))

      consumer
    end

    it "coerces a port given as a String into an Integer" do
      configuration.rabbitmq_port = "5673"

      expect(Bunny).to receive(:new).with(hash_including(port: 5673))

      consumer
    end

    it "leaves the port nil when none is configured" do
      configuration.rabbitmq_port = nil

      expect(Bunny).to receive(:new).with(hash_including(port: nil))

      consumer
    end

    it "adds the extra bunny options" do
      configuration.bunny_options = { verify_peer: true }

      expect(Bunny).to receive(:new).with(hash_including(verify_peer: true))

      consumer
    end

    it "lets the extra bunny options override the computed ones" do
      configuration.bunny_options = { host: "other.example.org" }

      expect(Bunny).to receive(:new).with(hash_including(host: "other.example.org"))

      consumer
    end

    it "tolerates nil bunny options" do
      configuration.bunny_options = nil

      expect { consumer }.not_to raise_error
    end

    it "builds the management client out of the scheme, the host and the management port" do
      expect(RabbitMQ::HTTP::Client).to receive(:new).with("http://rabbit.example.org:15672/", anything)

      consumer
    end

    it "honours a management scheme set to https" do
      configuration.rabbitmq_management_scheme = "https"

      expect(RabbitMQ::HTTP::Client).to receive(:new).with("https://rabbit.example.org:15672/", anything)

      consumer
    end

    it "falls back to http when no management scheme is configured" do
      configuration.rabbitmq_management_scheme = nil

      expect(RabbitMQ::HTTP::Client).to receive(:new).with("http://rabbit.example.org:15672/", anything)

      consumer
    end

    it "authenticates the management client with the broker credentials" do
      expect(RabbitMQ::HTTP::Client).to receive(:new).with(anything, hash_including(username: "guest", password: "secret"))

      consumer
    end

    it "adds the extra management options" do
      configuration.management_options = { verify: false }

      expect(RabbitMQ::HTTP::Client).to receive(:new).with(anything, hash_including(verify: false))

      consumer
    end

    it "lets the extra management options override the computed ones" do
      configuration.management_options = { username: "admin" }

      expect(RabbitMQ::HTTP::Client).to receive(:new).with(anything, hash_including(username: "admin"))

      consumer
    end

    it "tolerates nil management options" do
      configuration.management_options = nil

      expect { consumer }.not_to raise_error
    end

    it "does not open the connection yet" do
      expect(connection).not_to receive(:start)

      consumer
    end
  end

  describe "#wait_until_connected" do
    it "opens the connection" do
      expect(connection).to receive(:start)

      consumer.wait_until_connected
    end

    it "retries until the broker accepts the connection" do
      attempts = 0
      allow(connection).to receive(:start) do
        attempts += 1
        raise Bunny::TCPConnectionFailedForAllHosts if attempts < 3
      end
      allow(consumer).to receive(:sleep)

      consumer.wait_until_connected

      expect(attempts).to eq(3)
    end

    it "waits between two attempts" do
      call_count = 0
      allow(connection).to receive(:start) do
        call_count += 1
        raise Bunny::TCPConnectionFailedForAllHosts if call_count == 1
      end
      expect(consumer).to receive(:sleep).with(2)

      consumer.wait_until_connected
    end

    it "warns when an attempt fails" do
      call_count = 0
      allow(connection).to receive(:start) do
        call_count += 1
        raise Bunny::TCPConnectionFailedForAllHosts if call_count == 1
      end
      allow(consumer).to receive(:sleep)
      expect(logger).to receive(:warn).with("RabbitMQ connection failed, try again in 1 second.")

      consumer.wait_until_connected
    end

    it "does not swallow another connection error" do
      allow(connection).to receive(:start).and_raise(Bunny::AuthenticationFailureError.new("guest", "/", 1))

      expect { consumer.wait_until_connected }.to raise_error(Bunny::AuthenticationFailureError)
    end
  end

  describe "the channel setup" do
    it "creates a single-threaded channel that aborts on exception" do
      expect(connection).to receive(:create_channel).with(nil, 1, true).and_return(channel)

      consumer.wait_until_connected
    end

    it "applies the configured prefetch size" do
      configuration.rabbitmq_prefetch_size = 1000

      expect(channel).to receive(:basic_qos).with(1000)

      consumer.wait_until_connected
    end

    it "declares a durable queue" do
      expect(channel).to receive(:queue).with("happn-queue", durable: true, arguments: {}).and_return(queue)

      consumer.wait_until_connected
    end

    it "does not set x-queue-mode when no queue mode is configured" do
      expect(channel).to receive(:queue).with(anything, hash_including(arguments: {})).and_return(queue)

      consumer.wait_until_connected
    end

    it "passes the configured queue mode as x-queue-mode" do
      configuration.rabbitmq_queue_mode = "lazy"

      expect(channel).to receive(:queue).with(anything, hash_including(arguments: { "x-queue-mode" => "lazy" })).and_return(queue)

      consumer.wait_until_connected
    end

    it "declares a topic exchange" do
      expect(channel).to receive(:topic).with("events", durable: true).and_return(exchange)

      consumer.wait_until_connected
    end

    it "declares a transient exchange when durability is turned off" do
      configuration.rabbitmq_exchange_durable = false

      expect(channel).to receive(:topic).with("events", durable: false).and_return(exchange)

      consumer.wait_until_connected
    end
  end

  describe "the uncaught exception handler" do
    let(:exception) { StandardError.new("boom") }

    def trigger_uncaught_exception
      handler = nil
      allow(channel).to receive(:on_uncaught_exception) { |&block| handler = block }
      consumer.wait_until_connected
      handler.call(exception)
    end

    it "exits the process" do
      expect { trigger_uncaught_exception }.to raise_error(SystemExit) { |error| expect(error.status).to eq(1) }
    end

    it "reports the exception through the on_error hook" do
      reported            = []
      configuration.on_error = ->(error) { reported.push(error) }

      expect { trigger_uncaught_exception }.to raise_error(SystemExit)
      expect(reported).to eq([exception])
    end

    it "logs before exiting" do
      expect(logger).to receive(:error).with("An error occurred. Exiting events consumption.")

      expect { trigger_uncaught_exception }.to raise_error(SystemExit)
    end

    it "still exits when no on_error hook is configured" do
      configuration.on_error = nil

      expect { trigger_uncaught_exception }.to raise_error(SystemExit)
    end
  end

  describe "the bindings" do
    let(:projector) { Happn::SpecProjectors::CatchAll.new(silent_logger, repository) }

    before { projector }

    it "binds the queue to the exchange for every registered routing key" do
      projector.on(name: "create country", status: :new) { |event| event }
      projector.on(name: "delete country", status: :new) { |event| event }

      expect(queue).to receive(:bind).with(exchange, routing_key: "new.*.*.create country")
      expect(queue).to receive(:bind).with(exchange, routing_key: "new.*.*.delete country")

      consumer.wait_until_connected
    end

    it "binds a duplicated routing key only once" do
      projector.on(name: "create country") { |event| event }
      projector.on(name: "create country") { |event| event }

      expect(queue).to receive(:bind).with(exchange, routing_key: "*.*.*.create country").once

      consumer.wait_until_connected
    end

    it "binds nothing when no projector registered a subscription" do
      expect(queue).not_to receive(:bind)

      consumer.wait_until_connected
    end

    it "unbinds the routing keys that are no longer useful" do
      projector.on(name: "create country") { |event| event }
      allow(management).to receive(:list_queue_bindings).and_return([binding_double("*.*.*.create country"),
                                                                    binding_double("*.*.*.obsolete")])

      expect(queue).to receive(:unbind).with(exchange, routing_key: "*.*.*.obsolete")
      expect(queue).not_to receive(:unbind).with(exchange, routing_key: "*.*.*.create country")

      consumer.wait_until_connected
    end

    it "reads the existing bindings of the queue on the default vhost" do
      expect(management).to receive(:list_queue_bindings).with("/", "happn-queue").and_return([])

      consumer.wait_until_connected
    end

    it "reads the existing bindings on the vhost the broker connection uses" do
      configuration.bunny_options = { vhost: "/production" }

      expect(management).to receive(:list_queue_bindings).with("/production", "happn-queue").and_return([])

      consumer.wait_until_connected
    end

    it "resolves the vhost given under Bunny's 'virtual_host' spelling" do
      configuration.bunny_options = { virtual_host: "/production" }

      expect(management).to receive(:list_queue_bindings).with("/production", "happn-queue").and_return([])

      consumer.wait_until_connected
    end

    it "lets 'virtual_host' win over 'vhost', the way Bunny resolves them" do
      configuration.bunny_options = { virtual_host: "/production", vhost: "/staging" }

      expect(management).to receive(:list_queue_bindings).with("/production", "happn-queue").and_return([])

      consumer.wait_until_connected
    end

    it "leaves alone a binding coming from another exchange" do
      allow(management).to receive(:list_queue_bindings).and_return([binding_double("*.*.*.obsolete", source: "other-events")])

      expect(queue).not_to receive(:unbind)

      consumer.wait_until_connected
    end

    it "leaves alone the implicit binding to the default exchange" do
      allow(management).to receive(:list_queue_bindings).and_return([binding_double("happn-queue", source: "")])

      expect(queue).not_to receive(:unbind)

      consumer.wait_until_connected
    end

    it "unbinds nothing when every existing binding is still useful" do
      projector.on(name: "create country") { |event| event }
      allow(management).to receive(:list_queue_bindings).and_return([binding_double("*.*.*.create country")])

      expect(queue).not_to receive(:unbind)

      consumer.wait_until_connected
    end
  end

  describe "#start" do
    it "connects then consumes" do
      expect(consumer).to receive(:wait_until_connected).ordered
      expect(consumer).to receive(:consume).ordered

      consumer.start
    end

    it "subscribes to the queue with manual acknowledgements, blocking the caller" do
      expect(queue).to receive(:subscribe).with({ manual_ack: true, block: true })

      consumer.start
    end
  end

  describe "the consumption of a message" do
    let(:delivery_info) { double("delivery_info", delivery_tag: "delivery-tag-42") }
    let(:projector)     { Happn::SpecProjectors::Recording.new(silent_logger, repository) }

    before { projector.define_handlers }

    def consume(payload)
      allow(queue).to receive(:subscribe).and_yield(delivery_info, double("properties"), payload)
      consumer.start
    end

    it "builds an Event out of the JSON payload" do
      consume(build_event_payload(meta: { "id" => "event-1" }))

      expect(projector.consumed.map(&:id)).to eq(["event-1"])
    end

    it "runs the handler in the context of its projector" do
      consume(build_event_payload)

      expect(projector.consumed.size).to eq(1)
    end

    it "runs every matching handler" do
      projector.on(name: "create country") { |event| record(event) }

      consume(build_event_payload)

      expect(projector.consumed.size).to eq(2)
    end

    it "runs no handler when the event matches nothing" do
      consume(build_event_payload(meta: { "name" => "delete country" }))

      expect(projector.consumed).to be_empty
    end

    it "logs how many handlers are about to run" do
      expect(logger).to receive(:info).with("Executing 1 handlers for event 'create country' with id: event-1.")

      consume(build_event_payload(meta: { "id" => "event-1" }))
    end

    it "acknowledges the message once every handler ran" do
      expect(channel).to receive(:acknowledge).with("delivery-tag-42", false)

      consume(build_event_payload)
    end

    it "does not acknowledge a message whose handler raised" do
      projector.on(name: "create country") { raise "projector failed" }

      expect(channel).not_to receive(:acknowledge)

      expect { consume(build_event_payload) }.to raise_error("projector failed")
    end
  end

  describe "the failure of a handler" do
    let(:delivery_info) { double("delivery_info", delivery_tag: "delivery-tag-42") }
    let(:projector)     { Happn::SpecProjectors::CatchAll.new(silent_logger, repository) }

    before do
      projector.on { raise "projector failed" }
      allow(queue).to receive(:subscribe).and_yield(delivery_info, double("properties"), build_event_payload)
    end

    it "requeues the message" do
      expect(channel).to receive(:reject).with("delivery-tag-42", true)

      expect { consumer.start }.to raise_error("projector failed")
    end

    it "re-raises the exception so the caller decides what to do" do
      expect { consumer.start }.to raise_error(RuntimeError, "projector failed")
    end

    it "logs the exception" do
      expect(logger).to receive(:error).with(an_instance_of(RuntimeError))

      expect { consumer.start }.to raise_error("projector failed")
    end

    it "logs a fatal message" do
      expect(logger).to receive(:fatal).with("Can't handle event, exit.")

      expect { consumer.start }.to raise_error("projector failed")
    end

    it "reports a malformed payload the same way" do
      allow(queue).to receive(:subscribe).and_yield(delivery_info, double("properties"), "not json")

      expect(channel).to receive(:reject).with("delivery-tag-42", true)

      expect { consumer.start }.to raise_error(JSON::ParserError)
    end
  end
end
