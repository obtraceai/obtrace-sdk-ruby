require "net/http"
require "json"
require "uri"
require_relative "otel_setup"

module ObtraceSDK
  class Client
    @@initialized = false

    attr_reader :tracer, :meter, :handshake_ok

    def initialize(cfg)
      if @@initialized
        warn("[obtrace-sdk-ruby] already initialized, skipping duplicate init")
        return
      end

      raise ArgumentError, "api_key and service_name are required" if cfg.api_key.to_s.empty? || cfg.service_name.to_s.empty?

      @@initialized = true
      @cfg = cfg
      @handshake_ok = false
      @tracer_provider = OtelSetup.configure(cfg)
      @tracer = @tracer_provider.tracer("obtrace-sdk-ruby", ObtraceSDK::VERSION)
      @meter = nil
      @meter_warning_logged = false

      begin
        @meter = OpenTelemetry.meter_provider.meter("obtrace-sdk-ruby", ObtraceSDK::VERSION)
      rescue => _e
      end

      Thread.new { perform_handshake }
      at_exit { shutdown }
    end

    private def perform_handshake
      base = @cfg.ingest_base_url.to_s.chomp("/")
      return if base.empty?
      uri = URI("#{base}/v1/init")
      payload = JSON.generate({
        sdk: "obtrace-sdk-ruby",
        sdk_version: "1.0.0",
        service_name: @cfg.service_name,
        service_version: @cfg.service_version.to_s,
        runtime: "ruby",
        runtime_version: RUBY_VERSION,
      })
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 5
      http.read_timeout = 5
      req = Net::HTTP::Post.new(uri)
      req["Content-Type"] = "application/json"
      req["Authorization"] = "Bearer #{@cfg.api_key}"
      req.body = payload
      resp = http.request(req)
      if resp.code.to_i == 200
        @handshake_ok = true
        warn("[obtrace-sdk-ruby] init handshake OK") if @cfg.debug
      elsif @cfg.debug
        warn("[obtrace-sdk-ruby] init handshake failed: #{resp.code}")
      end
    rescue => e
      warn("[obtrace-sdk-ruby] init handshake error: #{e.message}") if @cfg.debug
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

      unless @meter
        unless @meter_warning_logged
          warn("[obtrace-sdk-ruby] meter provider not available, metrics will be dropped")
          @meter_warning_logged = true
        end
        return
      end

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
      exception = Exception.new(exception.to_s) unless exception.is_a?(Exception)

      attrs = {}
      context&.each { |k, v| attrs[k.to_s] = v.to_s }

      @tracer.in_span("error", attributes: attrs) do |s|
        s.record_exception(exception)
        s.status = OpenTelemetry::Trace::Status.error(exception.message.to_s)
      end
    end

    alias_method :capture_exception, :capture_error

    def shutdown
      @tracer_provider.shutdown if @tracer_provider.respond_to?(:shutdown)
    end
  end
end
