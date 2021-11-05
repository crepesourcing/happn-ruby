# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

### [1.0.0] - 05/11/2021

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
