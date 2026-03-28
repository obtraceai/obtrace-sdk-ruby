module ObtraceSDK
  class Middleware
    def initialize(app, client)
      @app = app
      @client = client
    end

    def call(env)
      trace_id = extract_trace_id(env) || Context.random_hex(16)
      span_id = Context.random_hex(8)
      start_ns = Otlp.now_unix_nano
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      status = nil
      error = nil

      begin
        status, headers, body = @app.call(env)
        [status, headers, body]
      rescue => e
        error = e
        raise
      ensure
        end_ns = Otlp.now_unix_nano
        duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)
        status_code = error ? 500 : status.to_i

        attrs = {
          "http.method" => env["REQUEST_METHOD"],
          "http.target" => env["PATH_INFO"],
          "http.host" => env["HTTP_HOST"].to_s,
          "http.scheme" => env["rack.url_scheme"].to_s,
          "http.status_code" => status_code,
          "http.duration_ms" => duration_ms,
          "http.user_agent" => env["HTTP_USER_AGENT"].to_s,
          "net.peer.ip" => (env["HTTP_X_FORWARDED_FOR"] || env["REMOTE_ADDR"]).to_s
        }

        if error
          attrs["error"] = true
          attrs["error.type"] = error.class.to_s
          attrs["error.message"] = error.message.to_s
        end

        if env["QUERY_STRING"] && !env["QUERY_STRING"].empty?
          attrs["http.query"] = env["QUERY_STRING"]
        end

        @client.span(
          "#{env["REQUEST_METHOD"]} #{env["PATH_INFO"]}",
          trace_id: trace_id,
          span_id: span_id,
          start_unix_nano: start_ns,
          end_unix_nano: end_ns,
          status_code: status_code >= 400 ? status_code : nil,
          status_message: error ? error.message : "",
          attrs: attrs
        )

        level = if status_code >= 500
          "error"
        elsif status_code >= 400
          "warn"
        else
          "info"
        end

        @client.log(
          level,
          "#{env["REQUEST_METHOD"]} #{env["PATH_INFO"]} #{status_code} #{duration_ms}ms",
          attrs
        )
      end
    end

    private

    def extract_trace_id(env)
      traceparent = env["HTTP_TRACEPARENT"]
      return nil unless traceparent
      parts = traceparent.split("-")
      return nil unless parts.length >= 3
      parts[1]
    end
  end
end
