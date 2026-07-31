require_relative "integration_helper"
require "tempfile"
require "rbconfig"

RSpec.describe "a projector handler raising inside a real consumer" do

  let(:queue_name)    { "happn-integration-#{SecureRandom.hex(4)}" }
  let(:exchange_name) { "happn-integration-#{SecureRandom.hex(4)}" }
  let(:event_name)    { "explode-#{SecureRandom.hex(4)}" }

  after { cleanup_queue(queue_name, exchange_name) }

  # `on_uncaught_exception` (lib/happn/event_consumer.rb) exits the process
  # once a handler raises, so this contract can only be observed from
  # outside the process running it: a child process is spawned, expected to
  # die with status 1, and the message it rejected must still be sitting in
  # the queue afterwards, ready for redelivery.
  def crash_recovery_script
    <<~RUBY
      $LOAD_PATH.unshift(#{lib_dir.inspect})
      require "happn"

      class ExplodingProjector < Happn::Projector
        def define_handlers
          on(name: #{event_name.inspect}) { |event| raise "boom from \#{event.name}" }
        end
      end

      Happn.configure do |config|
        config.logger                     = Logger.new(IO::NULL)
        config.rabbitmq_host              = #{rabbitmq_host.inspect}
        config.rabbitmq_port              = #{rabbitmq_port}
        config.rabbitmq_management_scheme = "http"
        config.rabbitmq_management_port   = #{rabbitmq_management_port}
        config.rabbitmq_user              = #{rabbitmq_user.inspect}
        config.rabbitmq_password          = #{rabbitmq_password.inspect}
        config.rabbitmq_queue_name        = #{queue_name.inspect}
        config.rabbitmq_exchange_name     = #{exchange_name.inspect}
        config.rabbitmq_exchange_durable  = false
        config.rabbitmq_prefetch_size     = 10
        config.projector_classes          = [ExplodingProjector]
      end

      Happn.init
      Happn.start
    RUBY
  end

  it "exits the process and leaves the message for redelivery" do
    script = Tempfile.new(["happn_integration_crash", ".rb"])
    script.write(crash_recovery_script)
    script.close
    log = Tempfile.new(["happn_integration_crash", ".log"])
    log.close

    pid = Process.spawn(RbConfig.ruby, script.path, out: log.path, err: log.path)

    begin
      wait_until(timeout: 10) do
        management_client.list_queue_bindings("/", queue_name).map(&:routing_key).include?("*.*.*.#{event_name}")
      rescue StandardError
        false
      end

      publish(exchange_name, "new.MyApplication.entity_change.#{event_name}",
              build_event_payload(meta: { "name" => event_name }))

      status = wait_for_exit(pid, timeout: 15)
      pid    = nil

      expect(status.exitstatus).to eq(1), "expected exit status 1, got #{status.inspect}. Child output:\n#{File.read(log.path)}"

      wait_until { queue_message_count(queue_name) == 1 }
    ensure
      if pid
        Process.kill("TERM", pid)
        Process.wait(pid)
      end
      script.unlink
      log.unlink
    end
  end
end
