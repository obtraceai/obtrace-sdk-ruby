require_relative "lib/obtrace_sdk/version"

Gem::Specification.new do |spec|
  spec.name          = "obtrace-sdk-ruby"
  spec.version       = ObtraceSDK::VERSION
  spec.authors       = ["Obtrace"]
  spec.email         = ["dev@obtrace.ai"]
  spec.summary       = "Obtrace Ruby SDK — observability for Ruby applications"
  spec.description   = "Ruby SDK for Obtrace observability platform. Captures logs, traces, and metrics via OTLP."
  spec.homepage      = "https://github.com/obtraceai/obtrace-sdk-ruby"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata["homepage_uri"]    = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"]   = "#{spec.homepage}/releases"

  spec.files = Dir["lib/**/*", "LICENSE", "README.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "net-http"
  spec.add_dependency "json"
end
