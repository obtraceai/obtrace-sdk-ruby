$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "minitest/autorun"
require "obtrace_sdk"

class ConfigTest < Minitest::Test
  def test_auto_instrument_http_defaults_true
    cfg = ObtraceSDK::Config.new(
      api_key: "k",
      ingest_base_url: "http://localhost",
      service_name: "svc"
    )
    assert_equal true, cfg.auto_instrument_http
  end

  def test_auto_capture_logs_defaults_true
    cfg = ObtraceSDK::Config.new(
      api_key: "k",
      ingest_base_url: "http://localhost",
      service_name: "svc"
    )
    assert_equal true, cfg.auto_capture_logs
  end

  def test_can_disable_auto_instrument_http
    cfg = ObtraceSDK::Config.new(
      api_key: "k",
      ingest_base_url: "http://localhost",
      service_name: "svc",
      auto_instrument_http: false
    )
    assert_equal false, cfg.auto_instrument_http
  end

  def test_can_disable_auto_capture_logs
    cfg = ObtraceSDK::Config.new(
      api_key: "k",
      ingest_base_url: "http://localhost",
      service_name: "svc",
      auto_capture_logs: false
    )
    assert_equal false, cfg.auto_capture_logs
  end
end
