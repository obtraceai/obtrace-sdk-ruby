$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "minitest/autorun"
require "obtrace_sdk"

class HttpInstrumentationTest < Minitest::Test
  def setup
    ObtraceSDK::HttpInstrumentation.reset!
    ObtraceSDK::LoggerCapture.reset!
  end

  def make_client(auto_http: true, auto_logs: false)
    cfg = ObtraceSDK::Config.new(
      api_key: "test-key",
      ingest_base_url: "http://localhost:19999",
      service_name: "test-svc",
      auto_instrument_http: auto_http,
      auto_capture_logs: auto_logs
    )
    ObtraceSDK::Client.new(cfg)
  end

  def test_install_sets_installed
    client = make_client
    assert ObtraceSDK::HttpInstrumentation.installed?
    assert_equal client, ObtraceSDK::HttpInstrumentation.client
  end

  def test_skip_when_disabled
    ObtraceSDK::HttpInstrumentation.reset!
    _client = make_client(auto_http: false)
    refute ObtraceSDK::HttpInstrumentation.installed?
  end

  def test_own_endpoint_detection
    client = make_client
    uri = URI.parse("http://localhost:19999/otlp/v1/logs")
    assert ObtraceSDK::HttpInstrumentation.own_endpoint?(uri)

    external_uri = URI.parse("http://example.com/api")
    refute ObtraceSDK::HttpInstrumentation.own_endpoint?(external_uri)
  end

  def test_traceparent_header_format
    headers = ObtraceSDK::Context.ensure_propagation_headers(
      {},
      trace_id: "a" * 32,
      span_id: "b" * 16
    )
    assert_match(/^00-[0-9a-f]{32}-[0-9a-f]{16}-01$/, headers["traceparent"])
  end

  def test_reset_clears_state
    _client = make_client
    assert ObtraceSDK::HttpInstrumentation.installed?
    ObtraceSDK::HttpInstrumentation.reset!
    refute ObtraceSDK::HttpInstrumentation.installed?
    assert_nil ObtraceSDK::HttpInstrumentation.client
  end
end
