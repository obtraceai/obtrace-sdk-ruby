require_relative "../lib/obtrace_sdk"

cfg = ObtraceSDK::Config.new(
  api_key: ENV.fetch("OBTRACE_API_KEY", "test-key"),
  ingest_base_url: ENV.fetch("OBTRACE_INGEST_BASE_URL", "https://inject.obtrace.ai"),
  service_name: "ruby-example",
  env: "dev"
)

client = ObtraceSDK::Client.new(cfg)
client.log("info", "ruby sdk initialized")
client.metric("example.counter", 1)
client.span("example.work")
client.flush
