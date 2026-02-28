module ObtraceSDK
  module Otlp
    module_function

    def attrs(hash)
      return [] if hash.nil?
      hash.map do |k, v|
        value =
          case v
          when TrueClass, FalseClass
            { "boolValue" => v }
          when Numeric
            { "doubleValue" => v.to_f }
          else
            { "stringValue" => v.to_s }
          end
        { "key" => k.to_s, "value" => value }
      end
    end

    def resource(cfg)
      base = {
        "service.name" => cfg.service_name,
        "service.version" => cfg.service_version,
        "deployment.environment" => cfg.env || "dev",
        "runtime.name" => "ruby"
      }
      base["obtrace.tenant_id"] = cfg.tenant_id if cfg.tenant_id
      base["obtrace.project_id"] = cfg.project_id if cfg.project_id
      base["obtrace.app_id"] = cfg.app_id if cfg.app_id
      base["obtrace.env"] = cfg.env if cfg.env
      attrs(base)
    end

    def now_unix_nano
      (Time.now.to_f * 1_000_000_000).to_i.to_s
    end

    def logs_payload(cfg, level, message, context = nil)
      context_attrs = { "obtrace.log.level" => level }
      if context
        context.each { |k, v| context_attrs["obtrace.attr.#{k}"] = v }
      end

      {
        "resourceLogs" => [
          {
            "resource" => { "attributes" => resource(cfg) },
            "scopeLogs" => [
              {
                "scope" => { "name" => "obtrace-sdk-ruby", "version" => "1.0.0" },
                "logRecords" => [
                  {
                    "timeUnixNano" => now_unix_nano,
                    "severityText" => level.to_s.upcase,
                    "body" => { "stringValue" => message.to_s },
                    "attributes" => attrs(context_attrs)
                  }
                ]
              }
            ]
          }
        ]
      }
    end

    def metric_payload(cfg, name, value, unit = "1", context = nil)
      {
        "resourceMetrics" => [
          {
            "resource" => { "attributes" => resource(cfg) },
            "scopeMetrics" => [
              {
                "scope" => { "name" => "obtrace-sdk-ruby", "version" => "1.0.0" },
                "metrics" => [
                  {
                    "name" => name.to_s,
                    "unit" => unit.to_s,
                    "gauge" => {
                      "dataPoints" => [
                        {
                          "timeUnixNano" => now_unix_nano,
                          "asDouble" => value.to_f,
                          "attributes" => attrs(context || {})
                        }
                      ]
                    }
                  }
                ]
              }
            ]
          }
        ]
      }
    end

    def span_payload(cfg, name, trace_id, span_id, start_unix_nano, end_unix_nano, status_code = nil, status_message = "", attrs_hash = nil)
      {
        "resourceSpans" => [
          {
            "resource" => { "attributes" => resource(cfg) },
            "scopeSpans" => [
              {
                "scope" => { "name" => "obtrace-sdk-ruby", "version" => "1.0.0" },
                "spans" => [
                  {
                    "traceId" => trace_id,
                    "spanId" => span_id,
                    "name" => name.to_s,
                    "kind" => 3,
                    "startTimeUnixNano" => start_unix_nano,
                    "endTimeUnixNano" => end_unix_nano,
                    "attributes" => attrs(attrs_hash || {}),
                    "status" => {
                      "code" => status_code && status_code.to_i >= 400 ? 2 : 1,
                      "message" => status_message.to_s
                    }
                  }
                ]
              }
            ]
          }
        ]
      }
    end
  end
end
