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
    end

    def log(level, message, context = nil)
      enqueue("/otlp/v1/logs", Otlp.logs_payload(@cfg, level, message, context))
    end

    def metric(name, value, unit = "1", context = nil)
      enqueue("/otlp/v1/metrics", Otlp.metric_payload(@cfg, name, value, unit, context))
    end

    def span(name, trace_id: nil, span_id: nil, start_unix_nano: nil, end_unix_nano: nil, status_code: nil, status_message: "", attrs: nil)
      trace_id ||= Context.random_hex(16)
      span_id ||= Context.random_hex(8)
      start_ns = start_unix_nano || Otlp.now_unix_nano
      end_ns = end_unix_nano || Otlp.now_unix_nano

      enqueue("/otlp/v1/traces", Otlp.span_payload(@cfg, name, trace_id, span_id, start_ns, end_ns, status_code, status_message, attrs))
      { trace_id: trace_id, span_id: span_id }
    end

    def inject_propagation(headers = {}, trace_id: nil, span_id: nil, session_id: nil)
      Context.ensure_propagation_headers(headers, trace_id: trace_id, span_id: span_id, session_id: session_id)
    end

    def flush
      batch = []
      @lock.synchronize do
        batch = @queue.dup
        @queue.clear
      end
      batch.each { |item| send_item(item) }
    end

    def shutdown
      flush
    end

    private

    def enqueue(endpoint, payload)
      @lock.synchronize do
        @queue.shift if @queue.length >= @cfg.max_queue_size
        @queue << { endpoint: endpoint, payload: payload }
      end
    end

    def send_item(item)
      uri = URI.parse("#{@cfg.ingest_base_url.to_s.sub(%r{/$}, "")}#{item[:endpoint]}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.read_timeout = @cfg.request_timeout_sec
      req = Net::HTTP::Post.new(uri.request_uri)
      req["Authorization"] = "Bearer #{@cfg.api_key}"
      req["Content-Type"] = "application/json"
      (@cfg.default_headers || {}).each { |k, v| req[k] = v.to_s }
      req.body = JSON.generate(item[:payload])
      res = http.request(req)
      if @cfg.debug && res.code.to_i >= 300
        warn("[obtrace-sdk-ruby] status=#{res.code} endpoint=#{item[:endpoint]} body=#{res.body}")
      end
    rescue StandardError => e
      warn("[obtrace-sdk-ruby] send failed endpoint=#{item[:endpoint]} err=#{e.message}") if @cfg.debug
    end
  end
end
