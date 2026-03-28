$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "minitest/autorun"
require "obtrace_sdk"

class MiddlewareTest < Minitest::Test
  def setup
    ObtraceSDK::HttpInstrumentation.reset!
    ObtraceSDK::LoggerCapture.reset!
  end

  def make_client
    cfg = ObtraceSDK::Config.new(
      api_key: "test-key",
      ingest_base_url: "http://localhost:19999",
      service_name: "test-svc",
      auto_instrument_http: false,
      auto_capture_logs: false
    )
    ObtraceSDK::Client.new(cfg)
  end

  def test_successful_request
    client = make_client
    inner_app = ->(env) { [200, { "Content-Type" => "text/plain" }, ["OK"]] }
    middleware = ObtraceSDK::Middleware.new(inner_app, client)

    env = {
      "REQUEST_METHOD" => "GET",
      "PATH_INFO" => "/health",
      "HTTP_HOST" => "localhost",
      "rack.url_scheme" => "http",
      "HTTP_USER_AGENT" => "test-agent",
      "REMOTE_ADDR" => "127.0.0.1"
    }

    status, headers, body = middleware.call(env)
    assert_equal 200, status
    assert_equal ["OK"], body
  end

  def test_error_request
    client = make_client
    inner_app = ->(env) { [500, { "Content-Type" => "text/plain" }, ["Error"]] }
    middleware = ObtraceSDK::Middleware.new(inner_app, client)

    env = {
      "REQUEST_METHOD" => "POST",
      "PATH_INFO" => "/api/broken",
      "HTTP_HOST" => "localhost",
      "rack.url_scheme" => "http",
      "REMOTE_ADDR" => "127.0.0.1"
    }

    status, _headers, _body = middleware.call(env)
    assert_equal 500, status
  end

  def test_exception_propagates
    client = make_client
    inner_app = ->(env) { raise RuntimeError, "boom" }
    middleware = ObtraceSDK::Middleware.new(inner_app, client)

    env = {
      "REQUEST_METHOD" => "GET",
      "PATH_INFO" => "/explode",
      "HTTP_HOST" => "localhost",
      "rack.url_scheme" => "http",
      "REMOTE_ADDR" => "127.0.0.1"
    }

    assert_raises(RuntimeError) { middleware.call(env) }
  end

  def test_extracts_traceparent
    client = make_client
    inner_app = ->(env) { [200, {}, ["OK"]] }
    middleware = ObtraceSDK::Middleware.new(inner_app, client)

    trace_id = "a" * 32
    env = {
      "REQUEST_METHOD" => "GET",
      "PATH_INFO" => "/traced",
      "HTTP_HOST" => "localhost",
      "rack.url_scheme" => "http",
      "REMOTE_ADDR" => "127.0.0.1",
      "HTTP_TRACEPARENT" => "00-#{trace_id}-#{"b" * 16}-01"
    }

    status, _headers, _body = middleware.call(env)
    assert_equal 200, status
  end

  def test_query_string_included
    client = make_client
    inner_app = ->(env) { [200, {}, ["OK"]] }
    middleware = ObtraceSDK::Middleware.new(inner_app, client)

    env = {
      "REQUEST_METHOD" => "GET",
      "PATH_INFO" => "/search",
      "QUERY_STRING" => "q=test&page=1",
      "HTTP_HOST" => "localhost",
      "rack.url_scheme" => "http",
      "REMOTE_ADDR" => "127.0.0.1"
    }

    status, _headers, _body = middleware.call(env)
    assert_equal 200, status
  end
end
