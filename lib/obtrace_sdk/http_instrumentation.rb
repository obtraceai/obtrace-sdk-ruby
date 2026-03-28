require "net/http"

module ObtraceSDK
  module HttpInstrumentation
    @client = nil
    @installed = false

    module_function

    def install(client)
      return if @installed
      @client = client
      @installed = true

      Net::HTTP.prepend(NetHttpPatch)
    end

    def client
      @client
    end

    def installed?
      @installed
    end

    def reset!
      @client = nil
      @installed = false
    end

    module NetHttpPatch
      def request(req, body = nil, &block)
        client = ObtraceSDK::HttpInstrumentation.client
        unless client
          return super
        end

        uri = URI.parse("#{use_ssl? ? 'https' : 'http'}://#{address}:#{port}#{req.path}")

        if uri.host && ObtraceSDK::HttpInstrumentation.own_endpoint?(uri)
          return super
        end

        trace_id = ObtraceSDK::Context.random_hex(16)
        span_id = ObtraceSDK::Context.random_hex(8)

        req["traceparent"] ||= "00-#{trace_id}-#{span_id}-01"

        start_ns = ObtraceSDK::Otlp.now_unix_nano
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        status_code = nil
        error = nil

        begin
          response = super
          status_code = response.code.to_i
          response
        rescue => e
          error = e
          raise
        ensure
          end_ns = ObtraceSDK::Otlp.now_unix_nano
          duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)

          attrs = {
            "http.method" => req.method,
            "http.url" => uri.to_s,
            "http.host" => uri.host.to_s,
            "net.peer.port" => uri.port.to_s,
            "http.duration_ms" => duration_ms,
            "auto.source" => "http_instrumentation"
          }

          if status_code
            attrs["http.status_code"] = status_code
          end

          if error
            attrs["error"] = true
            attrs["error.type"] = error.class.to_s
            attrs["error.message"] = error.message.to_s
          end

          span_status = if error
            status_code = 500
            500
          elsif status_code && status_code >= 400
            status_code
          else
            nil
          end

          client.span(
            "HTTP #{req.method}",
            trace_id: trace_id,
            span_id: span_id,
            start_unix_nano: start_ns,
            end_unix_nano: end_ns,
            status_code: span_status,
            status_message: error ? error.message : "",
            attrs: attrs
          )

          client.log(
            status_code && status_code >= 400 ? "warn" : "info",
            "HTTP #{req.method} #{uri.host}#{uri.path} #{status_code || 'ERR'}",
            attrs
          )
        end
      end
    end

    def self.own_endpoint?(uri)
      return false unless @client
      cfg = @client.instance_variable_get(:@cfg)
      return false unless cfg
      ingest_uri = URI.parse(cfg.ingest_base_url.to_s) rescue nil
      return false unless ingest_uri
      uri.host == ingest_uri.host && uri.port == ingest_uri.port
    end
  end
end
