require_relative "../spec/spec_helper"
require_relative "support/integration_spec_projectors"

require "securerandom"
require "timeout"

module Happn
  module IntegrationHelpers

    def rabbitmq_host
      ENV.fetch("RABBITMQ_HOST", "localhost")
    end

    def rabbitmq_port
      ENV.fetch("RABBITMQ_PORT", "5672").to_i
    end

    def rabbitmq_management_port
      ENV.fetch("RABBITMQ_MANAGEMENT_PORT", "15672").to_i
    end

    def rabbitmq_user
      ENV.fetch("RABBITMQ_USER", "happn")
    end

    def rabbitmq_password
      ENV.fetch("RABBITMQ_PASSWORD", "happn")
    end

    def lib_dir
      File.expand_path("../lib", __dir__)
    end

    def broker
      @broker ||= Bunny.new(host: rabbitmq_host, port: rabbitmq_port,
                            user: rabbitmq_user, password: rabbitmq_password).tap(&:start)
    end

    def management_client
      @management_client ||= RabbitMQ::HTTP::Client.new("http://#{rabbitmq_host}:#{rabbitmq_management_port}/",
                                                         username: rabbitmq_user, password: rabbitmq_password)
    end

    def publish(exchange_name, routing_key, payload)
      channel  = broker.create_channel
      channel.confirm_select
      exchange = channel.topic(exchange_name, durable: false)
      exchange.publish(payload, routing_key: routing_key)
      channel.wait_for_confirms
    ensure
      channel&.close
    end

    def queue_message_count(queue_name)
      channel = broker.create_channel
      channel.queue(queue_name, passive: true).message_count
    ensure
      channel&.close
    end

    def cleanup_queue(queue_name, exchange_name)
      channel = broker.create_channel
      channel.queue_delete(queue_name)
      channel.exchange_delete(exchange_name)
    rescue Bunny::NotFound
      nil
    ensure
      channel&.close
    end

    def wait_until(timeout: 5)
      Timeout.timeout(timeout) { sleep 0.05 until yield }
    rescue Timeout::Error
      raise "condition not met within #{timeout}s"
    end

    # Process.wait2 blocks indefinitely, which would hang the whole suite if
    # a spawned script never exits; poll it instead so a broken script times
    # out the example rather than the run.
    def wait_for_exit(pid, timeout: 15)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
      loop do
        _pid, status = Process.waitpid2(pid, Process::WNOHANG)
        return status if status

        raise "process #{pid} did not exit within #{timeout}s" if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

        sleep 0.1
      end
    end
  end
end

RSpec.configure do |config|
  config.include Happn::IntegrationHelpers
end
