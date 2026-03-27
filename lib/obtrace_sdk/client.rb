require "json"
require "net/http"
require "uri"
require "thread"
require_relative "context"
require_relative "otlp"

module ObtraceSDK
  class Client
    def initialize(cfg)
      raise ArgumentError, "api_key, ingest_base_url and service_name are required" if cfg.api_key.to_s.empty? || cfg.ingest_base_url.to_s.empty? || cfg.service_name.to_s.empty?

      @cfg = cfg
      @queue = []
      @lock = Mutex.new
      @http = nil
      @http_uri = nil
      @circuit_failures = 0
      @circuit_open_until = Time.at(0)
      @seen_exceptions = {}
      @seen_lock = Mutex.new

      install_exception_tracepoint
      at_exit { capture_fatal; shutdown }
    end

    def log(level, message, context = nil)
      enqueue("/otlp/v1/logs", Otlp.logs_payload(@cfg, level, truncate(message, 32768), context))
    end

    def metric(name, value, unit = "1", context = nil)
      warn("[obtrace-sdk-ruby] non-canonical metric name: #{name}") if @cfg.validate_semantic_metrics && @cfg.debug && !SemanticMetrics.semantic_metric?(name)
      enqueue("/otlp/v1/metrics", Otlp.metric_payload(@cfg, truncate(name, 1024), value, unit, context))
    end

    def span(name, trace_id: nil, span_id: nil, start_unix_nano: nil, end_unix_nano: nil, status_code: nil, status_message: "", attrs: nil)
      trace_id ||= Context.random_hex(16)
      span_id ||= Context.random_hex(8)
      start_ns = start_unix_nano || Otlp.now_unix_nano
      end_ns = end_unix_nano || Otlp.now_unix_nano

      name = truncate(name, 32768)
      if attrs
        attrs = attrs.transform_values { |v| v.is_a?(String) ? truncate(v, 4096) : v }
      end

      enqueue("/otlp/v1/traces", Otlp.span_payload(@cfg, name, trace_id, span_id, start_ns, end_ns, status_code, status_message, attrs))
      { trace_id: trace_id, span_id: span_id }
    end

    def inject_propagation(headers = {}, trace_id: nil, span_id: nil, session_id: nil)
      Context.ensure_propagation_headers(headers, trace_id: trace_id, span_id: span_id, session_id: session_id)
    end

    def flush
      batch = []
      @lock.synchronize do
        return if Time.now < @circuit_open_until
        half_open = @circuit_failures >= 5
        if half_open
          return if @queue.empty?
          batch = [@queue.shift]
        else
          batch = @queue.dup
          @queue.clear
        end
      end
      batch.each do |item|
        success = send_item(item)
        @lock.synchronize do
          if success
            if @circuit_failures > 0
              warn("[obtrace-sdk-ruby] circuit breaker closed") if @cfg.debug
              @circuit_failures = 0
              @circuit_open_until = Time.at(0)
            end
          else
            @circuit_failures += 1
            if @circuit_failures >= 5
              @circuit_open_until = Time.now + 30
              warn("[obtrace-sdk-ruby] circuit breaker opened") if @cfg.debug
            end
          end
        end
      end
    end

    def shutdown
      @tracepoint&.disable
      flush
      @lock.synchronize do
        if @http
          @http.finish rescue nil
          @http = nil
          @http_uri = nil
        end
      end
    end

    private

    def install_exception_tracepoint
      client = self
      @tracepoint = TracePoint.new(:raise) do |tp|
        ex = tp.raised_exception
        eid = ex.object_id
        seen = client.instance_variable_get(:@seen_lock).synchronize do
          cache = client.instance_variable_get(:@seen_exceptions)
          next true if cache[eid]
          cache[eid] = true
          cache.shift if cache.size > 200
          false
        end
        unless seen
          bt = (ex.backtrace || []).first(10).join("\n")
          client.log("error", "#{ex.class}: #{ex.message}", {
            "exception.type" => ex.class.to_s,
            "exception.message" => ex.message.to_s,
            "exception.stacktrace" => bt,
            "code.filepath" => tp.path.to_s,
            "code.lineno" => tp.lineno.to_s,
            "auto.source" => "tracepoint"
          })
        end
      end
      @tracepoint.enable
    end

    def capture_fatal
      return unless $!
      ex = $!
      bt = (ex.backtrace || []).first(10).join("\n")
      log("fatal", "#{ex.class}: #{ex.message}", {
        "exception.type" => ex.class.to_s,
        "exception.message" => ex.message.to_s,
        "exception.stacktrace" => bt,
        "auto.source" => "at_exit"
      })
    end

    def truncate(s, max)
      return s if s.length <= max
      s[0, max] + "...[truncated]"
    end

    def enqueue(endpoint, payload)
      @lock.synchronize do
        if @queue.length >= @cfg.max_queue_size
          @queue.shift
          warn("[obtrace-sdk-ruby] queue full, dropping oldest item") if @cfg.debug
        end
        @queue << { endpoint: endpoint, payload: payload.dup.freeze }
      end
    end

    def connection_for(uri)
      if @http && @http_uri && @http_uri.host == uri.host && @http_uri.port == uri.port
        begin
          return @http if @http.started?
        rescue StandardError
        end
      end

      @http.finish rescue nil if @http
      @http = Net::HTTP.new(uri.host, uri.port)
      @http.use_ssl = uri.scheme == "https"
      @http.read_timeout = @cfg.request_timeout_sec
      @http.start
      @http_uri = uri
      @http
    end

    def send_item(item)
      uri = URI.parse("#{@cfg.ingest_base_url.to_s.sub(%r{/$}, "")}#{item[:endpoint]}")
      http = connection_for(uri)
      req = Net::HTTP::Post.new(uri.request_uri)
      req["Authorization"] = "Bearer #{@cfg.api_key}"
      req["Content-Type"] = "application/json"
      (@cfg.default_headers || {}).each { |k, v| req[k] = v.to_s }
      req.body = JSON.generate(item[:payload])

      retries = 0
      begin
        res = http.request(req)
        if res.code.to_i >= 300
          warn("[obtrace-sdk-ruby] status=#{res.code} endpoint=#{item[:endpoint]} body=#{res.body}") if @cfg.debug
          return false
        end
        true
      rescue StandardError => e
        if retries < 2
          retries += 1
          sleep 1
          @http.finish rescue nil
          @http = nil
          http = connection_for(uri)
          retry
        end
        warn("[obtrace-sdk-ruby] send failed endpoint=#{item[:endpoint]} err=#{e.message}") if @cfg.debug
        false
      end
    end
  end
end
