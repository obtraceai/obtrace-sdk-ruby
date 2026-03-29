require "opentelemetry/sdk"
require "opentelemetry-exporter-otlp"

module ObtraceSDK
  module OtelSetup
    module_function

    def configure(cfg)
      endpoint = "#{cfg.ingest_base_url.to_s.sub(%r{/$}, "")}/otlp/v1/traces"

      exporter = OpenTelemetry::Exporter::OTLP::Exporter.new(
        endpoint: endpoint,
        headers: {
          "Authorization" => "Bearer #{cfg.api_key}"
        }.merge(cfg.default_headers || {}),
        timeout: cfg.request_timeout_sec
      )

      resource_attrs = {
        "service.name" => cfg.service_name,
        "service.version" => cfg.service_version,
        "deployment.environment" => cfg.env || "dev",
        "runtime.name" => "ruby"
      }
      resource_attrs["obtrace.tenant_id"] = cfg.tenant_id if cfg.tenant_id
      resource_attrs["obtrace.project_id"] = cfg.project_id if cfg.project_id
      resource_attrs["obtrace.app_id"] = cfg.app_id if cfg.app_id
      resource_attrs["obtrace.env"] = cfg.env if cfg.env

      OpenTelemetry::SDK.configure do |c|
        c.resource = OpenTelemetry::SDK::Resources::Resource.create(resource_attrs)
        c.add_span_processor(
          OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(exporter)
        )
        auto_detect_instrumentations(c)
      end

      OpenTelemetry.propagation = OpenTelemetry::Trace::Propagation::TraceContext.text_map_propagator

      OpenTelemetry.tracer_provider
    end

    def auto_detect_instrumentations(config)
      instrumentations = [
        ["OpenTelemetry::Instrumentation::Net::HTTP", "opentelemetry-instrumentation-net_http"],
        ["OpenTelemetry::Instrumentation::Rack", "opentelemetry-instrumentation-rack"],
        ["OpenTelemetry::Instrumentation::Rails", "opentelemetry-instrumentation-rails"],
        ["OpenTelemetry::Instrumentation::PG", "opentelemetry-instrumentation-pg"],
        ["OpenTelemetry::Instrumentation::Redis", "opentelemetry-instrumentation-redis"],
        ["OpenTelemetry::Instrumentation::Sidekiq", "opentelemetry-instrumentation-sidekiq"],
        ["OpenTelemetry::Instrumentation::Faraday", "opentelemetry-instrumentation-faraday"],
        ["OpenTelemetry::Instrumentation::ActiveRecord", "opentelemetry-instrumentation-active_record"]
      ]

      threads = instrumentations.map do |class_name, gem_name|
        Thread.new(class_name, gem_name) do |cn, gn|
          begin
            require gn.gsub("-", "/")
          rescue LoadError
          end
        end
      end
      threads.each(&:join)

      instrumentations.each do |class_name, gem_name|
        klass = Object.const_get(class_name) rescue next
        config.use(class_name) if klass
      end
    end
  end
end
