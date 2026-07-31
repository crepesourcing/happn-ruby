RSpec.describe Happn do

  let(:event_consumer) { instance_double(Happn::EventConsumer, start: nil, wait_until_connected: nil) }

  # `Happn` keeps its configuration, its logger and its consumer in module-level
  # instance variables. Every example works on a copy and puts the original
  # state back so the specs stay independent from each other.
  around do |example|
    previous_configuration = described_class.instance_variable_get(:@configuration)
    previous_logger        = described_class.instance_variable_get(:@logger)
    previous_consumer      = described_class.instance_variable_get(:@event_consumer)
    described_class.instance_variable_set(:@configuration, previous_configuration.dup)
    begin
      example.run
    ensure
      described_class.instance_variable_set(:@configuration, previous_configuration)
      described_class.instance_variable_set(:@logger, previous_logger)
      described_class.instance_variable_set(:@event_consumer, previous_consumer)
    end
  end

  before do
    Happn::SpecProjectors::Recording.reset!
    allow(Happn::EventConsumer).to receive(:new).and_return(event_consumer)
  end

  describe ".configure" do
    it "yields the configuration" do
      expect { |block| described_class.configure(&block) }.to yield_with_args(Happn::Configuration)
    end

    it "keeps the values set in the block" do
      described_class.configure { |config| config.rabbitmq_host = "rabbit.example.org" }

      expect(described_class.config.rabbitmq_host).to eq("rabbit.example.org")
    end

    it "reuses the same configuration across calls" do
      described_class.configure { |config| config.rabbitmq_host = "rabbit.example.org" }
      described_class.configure { |config| config.rabbitmq_user = "guest" }

      expect(described_class.config.rabbitmq_host).to eq("rabbit.example.org")
      expect(described_class.config.rabbitmq_user).to eq("guest")
    end
  end

  describe ".config" do
    it "exposes the default values shipped with the gem" do
      expect(described_class.config).to have_attributes(logger: nil,
                                                        rabbitmq_host: "localhost",
                                                        rabbitmq_port: 5672,
                                                        rabbitmq_management_scheme: "http",
                                                        rabbitmq_management_port: 15672,
                                                        rabbitmq_user: "",
                                                        rabbitmq_password: "",
                                                        rabbitmq_queue_name: "happn-queue",
                                                        rabbitmq_exchange_name: "events",
                                                        rabbitmq_exchange_durable: true,
                                                        rabbitmq_queue_mode: nil,
                                                        rabbitmq_prefetch_size: 10,
                                                        projector_classes: [],
                                                        bunny_options: {},
                                                        management_options: {},
                                                        on_error: nil)
    end
  end

  describe ".init" do
    it "uses the configured logger" do
      logger = silent_logger
      described_class.configure { |config| config.logger = logger }

      described_class.init

      expect(described_class.logger).to be(logger)
    end

    it "falls back to a standard output logger when none is configured" do
      described_class.configure { |config| config.logger = nil }

      described_class.init

      expect(described_class.logger).to be_a(Logger)
    end

    it "instantiates every configured projector class" do
      described_class.configure do |config|
        config.logger            = silent_logger
        config.projector_classes = [Happn::SpecProjectors::Recording]
      end

      described_class.init

      expect(Happn::SpecProjectors::Recording.instances.size).to eq(1)
    end

    it "asks every projector to define its handlers" do
      described_class.configure do |config|
        config.logger            = silent_logger
        config.projector_classes = [Happn::SpecProjectors::Recording]
      end

      described_class.init

      repository = Happn::SpecProjectors::Recording.instances.first.instance_variable_get(:@subscription_repository)
      expect(repository.find_all.size).to eq(1)
    end

    it "shares one single repository between every projector" do
      described_class.configure do |config|
        config.logger            = silent_logger
        config.projector_classes = [Happn::SpecProjectors::Recording, Happn::SpecProjectors::Recording]
      end

      described_class.init

      repositories = Happn::SpecProjectors::Recording.instances.map do |projector|
        projector.instance_variable_get(:@subscription_repository)
      end
      expect(repositories.uniq.size).to eq(1)
    end

    it "gives the Happn logger to the projectors" do
      logger = silent_logger
      described_class.configure do |config|
        config.logger            = logger
        config.projector_classes = [Happn::SpecProjectors::Recording]
      end

      described_class.init

      expect(Happn::SpecProjectors::Recording.instances.first.instance_variable_get(:@logger)).to be(logger)
    end

    it "logs how many projectors are about to be registered" do
      logger = instance_double(Logger, info: nil)
      described_class.configure do |config|
        config.logger            = logger
        config.projector_classes = [Happn::SpecProjectors::Recording]
      end

      expect(logger).to receive(:info).with("1 projector are going to be registered...")

      described_class.init
    end

    it "logs each registered projector" do
      logger = instance_double(Logger, info: nil)
      described_class.configure do |config|
        config.logger            = logger
        config.projector_classes = [Happn::SpecProjectors::Recording]
      end

      expect(logger).to receive(:info).with("Projector 'Happn::SpecProjectors::Recording' registered")

      described_class.init
    end

    it "builds the event consumer with the logger, the configuration and the repository" do
      logger = silent_logger
      described_class.configure { |config| config.logger = logger }

      expect(Happn::EventConsumer).to receive(:new)
        .with(logger, described_class.config, an_instance_of(Happn::SubscriptionRepository))
        .and_return(event_consumer)

      described_class.init
    end

    it "registers nothing when no projector class is configured" do
      described_class.configure do |config|
        config.logger            = silent_logger
        config.projector_classes = []
      end

      expect { described_class.init }.not_to raise_error
      expect(Happn::SpecProjectors::Recording.instances).to be_empty
    end
  end

  describe ".start" do
    it "starts the event consumer" do
      described_class.configure { |config| config.logger = silent_logger }
      described_class.init

      expect(event_consumer).to receive(:start)

      described_class.start
    end
  end

  describe ".create_queue_only" do
    before { described_class.configure { |config| config.logger = silent_logger } }

    it "declares the queue without consuming anything" do
      expect(event_consumer).to receive(:wait_until_connected)
      expect(event_consumer).not_to receive(:start)

      described_class.create_queue_only
    end

    it "initializes Happn on the way" do
      described_class.create_queue_only

      expect(described_class.logger).to be_a(Logger)
    end
  end

  describe ".logger" do
    it "is nil before init" do
      described_class.instance_variable_set(:@logger, nil)

      expect(described_class.logger).to be_nil
    end
  end
end
