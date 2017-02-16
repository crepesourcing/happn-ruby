# Gem for happn

Happn connects a RabbitMQ exchange and listens for CREPE events (possibly generated using `flu-rails`) sequentially.
Happn helps developers to create _"Projectors"_ that define how to match and consume events.

This gem connects a single RabbitMQ queue and bind it automatically to its exchange. These bindings are defined by developers through "matchers" when loading projectors.

## Requirements

* Ruby 2.2
* Tested with RabbitMQ 3.5.8
* `happn-ruby` works with or without Rails (tested with Rails 4 and 5).

## Installation

Add the gem to your project's Gemfile:

  ```ruby
  gem "happn", git: "https://github.com/crepesourcing/happn-ruby.git"
  ```

Then, configure `Happn`. If you use Rails, you can create an initializer into your Rails app (`config/initializers/happn.rb`). This code can be called anywhere before starting `Happn.init`.
  ```ruby
  Happn.configure do |config|
    config.logger                     = Rails.logger
    config.rabbitmq_host              = ENV["RABBITMQ_HOST"]
    config.rabbitmq_port              = ENV["RABBITMQ_PORT"]
    config.rabbitmq_management_port   = ENV["RABBITMQ_MANAGEMENT_PORT"]
    config.rabbitmq_user              = ENV["RABBITMQ_USER"]
    config.rabbitmq_password          = ENV["RABBITMQ_PASSWORD"]
    config.rabbitmq_queue_name        = ENV["CONSUMER_QUEUE_NAME"]
    config.rabbitmq_exchange_name     = ENV["RABBITMQ_EXCHANGE_NAME"]
    config.rabbitmq_exchange_durable  = ENV["RABBITMQ_EXCHANGE_DURABLE"] == "true"
    config.projector_classes          = [LoggerProjector]
  end
  ```

Each configuration is detailed below.

## About queues

* `Happn` consumes a single queue through the RabbitMQ's [Topic Exchange Model](https://www.rabbitmq.com/tutorials/amqp-concepts.html#exchange-topic).
* If the queue does not exist when `Happn` starts, it is created automatically.
* When connecting a queue, please be careful that each connection parameter must match the existing queue's parameters. For instance, the value of `x-queue-mode` must match to avoid a `PRECONDITION FAILED` error.
* All bindings between queues and their exchange are reset when starting `Happn`. Based on all the projectors that have been registered (option `projector_classes`), `Happn` detects which events must be consumed and binds its queue to the exchange depending on these event matchers.

## About projectors

A projector:
* defines one or multiple matchers to detect which events must be consumed. Matchers can be declared using 4 event properties
  * `emitter`: _e.g._ `Facebook` or `MyInternalApi` (`:all` or no value mean "all emitters")
  * `kind`: _e.g._ `entity_change` or `kind` (`:all` or no value mean "all kinds")
  * `name`: _e.g._ `create country` or `request to destroy bunnies` (`:all` or no value mean "all names")
  * `status`: _e.g._ `:new` or `:replayed` (`:all` or no value mean "all statuses")
* defines how to consume these events.

When a projector raises an Error, `Happn` stops.

## Usage

### Start Up

Starting `Happn` consumes events sequentially. For instance, it can be started from a `Rake` tasks:
  ```ruby
  namespace :events do
    desc "Listen all events and consume them."
    task consume: :environment do
      Happn.init
      Happn.start
    end
  end
  ```

### Define a Projector

A projector is a class that defines how to consume one or multiple types of events. This class must:

* extend `Happn::Projector`.
* use its `on` method to declare _which_ events to match and _how_ to consume them. This must be done in a `define_handlers` method.

```ruby
class LoggerProjector < Happn::Projector
  def define_handlers
    on emitter: "MyApplication", name: "create country" do |event|
      Rails.logger("A country has been created and generated an event with id #{event.id}")
    end

    on kind: "request", status: :new do |event|
      Rails.logger("This is a new request to the controller: #{event.data["controller_name"]}")
    end
  end
end
```

### Registering all projectors automatically

If all subclass of `Happn::Projector` should be registered seamlessly, the configuration can declare the following code (using Rails):
```ruby
Happn.configure do |config|
  Rails.application.eager_load!
  config.projector_classes = Happn::Projector.descendants
end
```

## Overall configuration options

All options have a default value. However, all of them can be changed in your `Happn.configure` block.

| Option | Default Value | Type | Required? | Description  | Example |
| ---- | ----- | ------ | ----- | ------ | ----- |
| `logger` | `Logger.new(STDOUT)`| Logger | Optional | The logger used by `happn` | `Rails.logger` | 
| `rabbitmq_host` | `"localhost"` | String | Required | RabbitMQ exchange's host. | `"192.168.42.42"` |
| `rabbitmq_port` | `"5672"` | String | Required | RabbitMQ exchange's port. | `"1234"` |
| `rabbitmq_user` | `""` | String | Required | RabbitMQ exchange's username. | `"root"` |
| `rabbitmq_password` | `""` | String | Required | RabbitMQ exchange's password. | `"pouet"` |
| `rabbitmq_exchange_name` | `"events"` | String | Required | RabbitMQ exchange's name. | `"myproject"` |
| `rabbitmq_management_port` | `"15672"` | String | Required | RabbitMQ exchange's management port. This port is used when `happn` must access metadata information about queues, messages, etc. This port is used to create/delete bindings between the queue and its exchange. | `"4242"` |
| `rabbitmq_queue_name` | `"happn-queue"` | String | Required | The RabbitMQ queue to create, bind and consume. If the queue does not exist, it will be created at startup. | `"my-queue"` |
| `rabbitmq_exchange_durable` | `true` | Boolean | Optional | Make the RabbitMQ's exchange durable or not. From RabbitMQ's [documentation](https://www.rabbitmq.com/tutorials/amqp-concepts.html#exchanges): _"Durable exchanges survive broker restart whereas transient exchanges do not (they have to be redeclared when broker comes back online)."_ | `false` |
| `rabbitmq_queue_mode` | `nil` | String | Optional | When creating the queue, this option can be passed to set `x-queue-mode`. For instance, a queue can be made _"lazy"_ by passing `"lazy"` as a value. See [RabbitMQ's documentation](https://www.rabbitmq.com/lazy-queues.html) for more details.  | `lazy` |
| `rabbitmq_prefetch_size` | `10` | Integer | Optional | Also known as RabbitMQ's QOS. From the [RabbitMQ's documentation](http://www.rabbitmq.com/consumer-prefetch.html): _"AMQP specifies the basic.qos method to allow you to limit the number of unacknowledged messages on a channel (or connection) when consuming (aka "prefetch count")."_ | `1000` |
| `projector_classes` | `[]` | Array of constants | Required | All Projector classes to register. This value can be generated by reading all descendant classes from `Happn::Projector`. | `[MyProjector]` |
