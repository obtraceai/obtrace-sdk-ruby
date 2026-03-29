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
- `service_name`

Optional (defaults to `https://ingest.obtrace.ai`):
- `ingest_base_url`

Optional (auto-resolved from API key on the server side):
- `tenant_id`
- `project_id`
- `app_id`
- `env`
- `service_version`

## Quickstart

### Simplified setup

The API key resolves `tenant_id`, `project_id`, `app_id`, and `env` automatically on the server side, so only two fields are needed:

```ruby
require "obtrace_sdk"

cfg = ObtraceSDK::Config.new(
  api_key: "obt_live_...",
  service_name: "my-service"
)

client = ObtraceSDK::Client.new(cfg)
```

### Full configuration

For advanced use cases you can override the resolved values explicitly:

```ruby
require_relative "lib/obtrace_sdk"

cfg = ObtraceSDK::Config.new(
  api_key: "<API_KEY>",
  service_name: "ruby-api"
)

client = ObtraceSDK::Client.new(cfg)
client.log("info", "started")
client.metric(ObtraceSDK::SemanticMetrics::RUNTIME_CPU_UTILIZATION, 0.41)
client.span("checkout.charge", attrs: {
  "feature.name" => "checkout",
  "payment.provider" => "stripe"
})
client.flush
```

## Canonical metrics and custom spans

- Use `ObtraceSDK::SemanticMetrics::*` for globally normalized metric names.
- Custom spans use `client.span("name", attrs: {...})`.
- Keep free-form metric names only for application-specific signals outside the shared catalog.

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
