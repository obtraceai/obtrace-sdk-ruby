require_relative "otel_setup"

module ObtraceSDK
  class Client
    attr_reader :tracer, :meter

    def initialize(cfg)
      raise ArgumentError, "api_key, ingest_base_url and service_name are required" if cfg.api_key.to_s.empty? || cfg.ingest_base_url.to_s.empty? || cfg.service_name.to_s.empty?

      @cfg = cfg
      @tracer_provider = OtelSetup.configure(cfg)
      @tracer = @tracer_provider.tracer("obtrace-sdk-ruby", ObtraceSDK::VERSION)
      @meter = nil

      begin
        @meter = OpenTelemetry.meter_provider.meter("obtrace-sdk-ruby", ObtraceSDK::VERSION)
      rescue => _e
      end

      at_exit { shutdown }
    end

    def log(level, message, context = nil)
      attributes = { "obtrace.log.level" => level.to_s }
      if context
        context.each { |k, v| attributes["obtrace.attr.#{k}"] = v.to_s }
      end
      attributes["log.severity"] = level.to_s.upcase
      attributes["log.message"] = message.to_s

      span = OpenTelemetry::Trace.current_span
      if span && span.context.valid?
        span.add_event("log", attributes: attributes)
      else
        @tracer.in_span("log.#{level}", attributes: attributes) { |_s| }
      end
    end

    def metric(name, value, unit = "1", context = nil)
      warn("[obtrace-sdk-ruby] non-canonical metric name: #{name}") if @cfg.validate_semantic_metrics && @cfg.debug && !SemanticMetrics.semantic_metric?(name)

      return unless @meter

      attrs = {}
      context&.each { |k, v| attrs[k.to_s] = v.to_s }

      gauge = @meter.create_gauge(name.to_s, unit: unit.to_s)
      gauge.set(value.to_f, attributes: attrs)
    end

    def span(name, attrs: nil, &block)
      span_attrs = {}
      if attrs
        attrs.each { |k, v| span_attrs[k.to_s] = v.is_a?(Numeric) || v.is_a?(TrueClass) || v.is_a?(FalseClass) ? v : v.to_s }
      end

      if block
        @tracer.in_span(name.to_s, attributes: span_attrs) do |s|
          block.call(s)
        end
      else
        @tracer.in_span(name.to_s, attributes: span_attrs) { |_s| }
      end
    end

    def capture_error(exception, context = nil)
      attrs = {}
      context&.each { |k, v| attrs[k.to_s] = v.to_s }

      @tracer.in_span("error", attributes: attrs) do |s|
        s.record_exception(exception)
        s.status = OpenTelemetry::Trace::Status.error(exception.message.to_s)
      end
    end

    def shutdown
      @tracer_provider.shutdown if @tracer_provider.respond_to?(:shutdown)
    end
  end
end
