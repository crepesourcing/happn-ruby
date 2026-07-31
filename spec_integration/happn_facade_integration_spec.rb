require_relative "integration_helper"

RSpec.describe "the public Happn workflow" do

  let(:queue_name)    { "happn-integration-#{SecureRandom.hex(4)}" }
  let(:exchange_name) { "happn-integration-#{SecureRandom.hex(4)}" }

  after { cleanup_queue(queue_name, exchange_name) }

  it "connects, binds, consumes and dispatches a real message through Happn.configure/init/start" do
    Happn::IntegrationSpecProjectors::Recording.reset!
    Happn::IntegrationSpecProjectors::Recording.matcher = { name: "create country", status: :new }

    Happn.configure do |config|
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
      config.projector_classes          = [Happn::IntegrationSpecProjectors::Recording]
      config.bunny_options              = {}
      config.management_options         = {}
    end

    Happn.create_queue_only
    publish(exchange_name, "new.MyApplication.entity_change.create country", build_event_payload)

    thread = Thread.new { Happn.start }
    begin
      wait_until { Happn::IntegrationSpecProjectors::Recording.instances.last&.consumed&.any? }
    ensure
      thread.kill
      thread.join(2)
    end

    expect(Happn::IntegrationSpecProjectors::Recording.instances.last.consumed.map(&:name)).to eq(["create country"])
  end
end
