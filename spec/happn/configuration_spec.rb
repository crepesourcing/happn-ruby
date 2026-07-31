options = [
  :logger,
  :rabbitmq_host,
  :rabbitmq_port,
  :rabbitmq_management_port,
  :rabbitmq_management_scheme,
  :rabbitmq_user,
  :rabbitmq_password,
  :rabbitmq_queue_name,
  :rabbitmq_exchange_name,
  :rabbitmq_exchange_durable,
  :rabbitmq_queue_mode,
  :rabbitmq_prefetch_size,
  :projector_classes,
  :bunny_options,
  :management_options,
  :on_error
].freeze

RSpec.describe Happn::Configuration do

  subject(:configuration) { described_class.new }

  options.each do |option|
    it "reads back the '#{option}' it was given" do
      configuration.public_send("#{option}=", "a value")

      expect(configuration.public_send(option)).to eq("a value")
    end
  end

  it "starts with every option unset" do
    expect(options.map { |option| configuration.public_send(option) }).to all(be_nil)
  end

  it "does not answer to an unknown option" do
    expect(configuration).not_to respond_to(:rabbitmq_unknown_option)
  end
end
