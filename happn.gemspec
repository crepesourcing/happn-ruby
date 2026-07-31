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
  spec.description   = "Happn connects a RabbitMQ topic exchange and consumes CREPE events sequentially. " \
                       "It lets developers declare \"projectors\" that match events on their emitter, kind, " \
                       "name and status, and binds its queue to the exchange according to those matchers."
  spec.homepage      = "https://github.com/crepesourcing/happn-ruby"
  spec.license       = "MIT"

  spec.required_ruby_version = ">= 3.2"

  spec.metadata = {
    "source_code_uri"       => spec.homepage,
    "changelog_uri"         => "#{spec.homepage}/blob/main/CHANGELOG.md",
    "bug_tracker_uri"       => "#{spec.homepage}/issues",
    "rubygems_mfa_required" => "true"
  }

  spec.files         = `git ls-files -z`.split("\x0").reject do |file|
    file.start_with?("spec/", ".github/", ".claude/") ||
      [".gitignore", ".rspec", "Gemfile", "Rakefile"].include?(file)
  end
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler",                    ">=1.17"
  spec.add_development_dependency "rake",                       ">= 13.0"
  spec.add_development_dependency "rspec",                      "~>3.0"
  spec.add_dependency             "bunny",                      ">=2.19.0"
  spec.add_dependency             "rabbitmq_http_api_client",   ">=2.0.0"
end
