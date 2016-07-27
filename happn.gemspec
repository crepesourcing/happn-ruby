# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "happn/version"

Gem::Specification.new do |spec|
  spec.name          = "happn"
  spec.version       = Happn::VERSION
  spec.authors       = ["Commuty"]
  spec.email         = ["support@commuty.net"]
  spec.summary       = "Gem to connect a RabbitMQ exchange and listen for events."
  spec.description   = "Gem to connect a RabbitMQ exchange and listen for events."
  spec.homepage      = "https://gitlab.spin42.me/commuty/happn"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "1.12.5"
  spec.add_dependency             "bunny",   ">=2.5.0"
  spec.add_dependency             "activesupport"
end
