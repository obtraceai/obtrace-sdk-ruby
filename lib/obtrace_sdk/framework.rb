module ObtraceSDK
  module Framework
    module_function

    # Rack-compatible middleware baseline used by Rails.
    def rack_middleware(client, app)
      lambda do |env|
        client.log("info", "request.start", { method: env["REQUEST_METHOD"], path: env["PATH_INFO"] })
        status, headers, body = app.call(env)
        client.log("info", "request.finish", { status: status.to_i })
        [status, headers, body]
      end
    end
  end
end
