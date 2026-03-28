module ObtraceSDK
  class Middleware
    def initialize(app, client)
      @app = app
      @client = client
      @tracer = client.tracer
    end

    def call(env)
      span_name = "#{env["REQUEST_METHOD"]} #{env["PATH_INFO"]}"

      extracted_context = extract_context(env)

      span_attrs = {
        "http.method" => env["REQUEST_METHOD"].to_s,
        "http.target" => env["PATH_INFO"].to_s,
        "http.host" => env["HTTP_HOST"].to_s,
        "http.scheme" => (env["rack.url_scheme"] || "http").to_s,
        "http.user_agent" => env["HTTP_USER_AGENT"].to_s,
        "net.peer.ip" => (env["HTTP_X_FORWARDED_FOR"] || env["REMOTE_ADDR"]).to_s
      }

      if env["QUERY_STRING"] && !env["QUERY_STRING"].empty?
        span_attrs["http.query"] = env["QUERY_STRING"]
      end

      OpenTelemetry::Context.with_current(extracted_context) do
        @tracer.in_span(span_name, attributes: span_attrs, kind: :server) do |s|
          begin
            status, headers, body = @app.call(env)
            s.set_attribute("http.status_code", status.to_i)
            if status.to_i >= 500
              s.status = OpenTelemetry::Trace::Status.error("HTTP #{status}")
            end
            [status, headers, body]
          rescue => e
            s.record_exception(e)
            s.status = OpenTelemetry::Trace::Status.error(e.message.to_s)
            s.set_attribute("http.status_code", 500)
            raise
          end
        end
      end
    end

    private

    def extract_context(env)
      traceparent = env["HTTP_TRACEPARENT"]
      return OpenTelemetry::Context.current unless traceparent

      OpenTelemetry.propagation.extract(
        env,
        getter: OpenTelemetry::Common::Propagation.rack_env_getter
      )
    rescue
      OpenTelemetry::Context.current
    end
  end
end
