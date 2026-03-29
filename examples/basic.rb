require_relative "../lib/obtrace_sdk"

cfg = ObtraceSDK::Config.new(
  api_key: ENV.fetch("OBTRACE_API_KEY", "test-key"),
  service_name: "ruby-example",
  env: "dev"
)

client = ObtraceSDK::Client.new(cfg)
client.log("info", "ruby sdk initialized")
client.metric(ObtraceSDK::SemanticMetrics::RUNTIME_CPU_UTILIZATION, 0.41)
client.span("checkout.charge", attrs: { "feature.name" => "checkout", "payment.provider" => "stripe" }) do |s|
  client.log("info", "processing charge")
end

begin
  raise StandardError, "test error"
rescue => e
  client.capture_error(e, { "context" => "example" })
end

client.shutdown
