# obtrace-sdk-ruby

Ruby backend SDK for Obtrace telemetry transport and instrumentation.

## Scope
- OTLP logs/traces/metrics transport
- Context propagation
- Rack/Rails middleware baseline

## Design Principle
SDK is thin/dumb.
- No business logic authority in client SDK.
- Policy and product logic are server-side.

## Install

```bash
# when published as gem
gem install obtrace-sdk-ruby
```

Current workspace usage:

```ruby
require_relative "lib/obtrace_sdk"
```

## Configuration

Required:
- `api_key`
- `ingest_base_url`
- `service_name`

Recommended:
- `tenant_id`
- `project_id`
- `app_id`
- `env`
- `service_version`

## Quickstart

```ruby
require_relative "lib/obtrace_sdk"

cfg = ObtraceSDK::Config.new(
  api_key: "<API_KEY>",
  ingest_base_url: "https://injet.obtrace.ai",
  service_name: "ruby-api"
)

client = ObtraceSDK::Client.new(cfg)
client.log("info", "started")
client.metric("orders.count", 1)
client.span("job.process")
client.flush
```

## Frameworks

- Rack-compatible middleware baseline for Rails usage
- Reference docs:
  - `docs/frameworks.md`

## Production Hardening

1. Keep API keys in environment/secret managers.
2. Separate keys per environment.
3. Use graceful shutdown hooks to flush queue before exit.
4. Validate telemetry flow after deploy.

## Troubleshooting

- Missing telemetry: verify endpoint reachability and auth key.
- Missing correlation: ensure propagation headers are injected.
- Debug transport with `debug: true` in config.

## Documentation
- Docs index: `docs/index.md`
- LLM context file: `llm.txt`
- MCP metadata: `mcp.json`

## Reference
