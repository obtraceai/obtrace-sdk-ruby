# Getting Started

```ruby
require_relative "../lib/obtrace_sdk"

cfg = ObtraceSDK::Config.new(
  api_key: "<API_KEY>",
  ingest_base_url: "https://inject.obtrace.ai",
  service_name: "ruby-api"
)

client = ObtraceSDK::Client.new(cfg)
client.log("info", "started")
client.flush
```
