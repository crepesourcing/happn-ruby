# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

### [Unreleased]

* `Happn` no longer runs a handler several times for a single event. `"all"` is both the wildcard a query is stored under and a value an event may legitimately carry, and the dispatch used to list it twice: an event whose `emitter`, `kind` and `status` were all `"all"` ran each of its matching handlers 8 times, and 16 times when its `name` carried it too.
* `Happn` now reads the existing bindings of its queue on the vhost its broker connection uses, instead of always on the default one. On any other vhost it used to read someone else's bindings, and to unbind legitimate ones from its own queue as a result. Both `vhost` and `virtual_host` are honoured in `bunny_options`, with the precedence Bunny gives them.
* `Happn` now only unbinds the routing keys bound to its own exchange. It used to consider every binding of the queue, whatever its source, so the implicit binding each queue carries to the default exchange triggered a useless `unbind` on every start up.
* `Happn.stop` stops the consumption started by `Happn.start` and releases the thread it blocks. It cancels the consumer, lets the messages already handed over run to completion, then closes the broker connection.
* `Happn` builds an event from its payload about 5 times faster. The conversion of a payload key into an underscored symbol is now memoized instead of being recomputed on every key of every message.
* `Happn` allocates far fewer arrays while looking up the handlers of an event: the list under construction is filled in place instead of being reallocated on each of the 16 combinations looked up, which also lightens the garbage collector on a busy queue.
* `Happn.register` is now really private. It was meant to be, and read as such, but the `private` guarding it had no effect on a method defined on the module itself, leaving it callable from the outside.
* Publishing a version now requires the whole test suite to pass.

### [1.1.7] - 2026-08-01

* **Breaking**: `required_ruby_version` is raised from `>= 3.0` to `>= 3.2`.
* `Happn::EventConsumer` now requires `json` explicitly.
* `Happn::Event#timestamp` returns `nil` again for an empty or blank timestamp, as it did up to 1.0.3 through `String#to_datetime`.
* Integration tests with RabbitMQ.

### [1.1.6] - 2026-07-31

* Suite of tests
* Gem metadata: source code, changelog, `required_ruby_version >= 3.0`, a real description, and a package restricted to the library itself
* `Happn::Event#has_change?` and `Happn::Event#delete_change` now accept an attribute name given as a `String`, like `change_before` and `change_after` already did. They used to silently match nothing in that case.
* A query attribute explicitly set to `nil` now means _"all"_, as documented, instead of producing an empty word in the routing key. `Happn::Query` normalizes it into `:all` at build time, so the binding declared on the exchange and the local dispatch of the event agree with each other.

### [1.1.0] - 2026-07-30

* Remove the `activesupport` dependency: `Happn::Configuration` no longer relies on `ActiveSupport::Configurable`, and `Happn::Event` no longer relies on `String#to_datetime` / `Object#try`
* Relax the `bundler` development dependency from a pinned `1.12.5` to `>=1.17`

### [1.0.3] - 2024-12-04

* Replace the use of `to_time` to `to_datetime`

### [1.0.2] - 2021-11-06

* Breaking change : force every `port` to be an integer
* Add `management_options`

### [1.0.0] - 2021-11-05

* Add `bunny_options`
* Add `rabbitmq_management_scheme`
* MIT License

### [0.1.4]

* Add convenient method `Event.request_metadata`

### [0.1.3]

* Use of `rabbitmq_http_api_client >= 2.0.0` and `bunny >= 2.19.0`

### [0.1.2]

* Use of `rabbitmq_http_api_client:1.14.0`, which supports `faraday >= 1`

### [0.1.1]

* Happn now raise an exception instead of exiting the process when the consumption of an event fails, allowing the gem user to decide how to handle it.
