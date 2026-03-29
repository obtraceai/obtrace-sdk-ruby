$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "minitest/autorun"
require "obtrace_sdk"

class ConfigTest < Minitest::Test
  def test_required_fields
    cfg = ObtraceSDK::Config.new(
      api_key: "k",
      service_name: "svc"
    )
    assert_equal "k", cfg.api_key
    assert_equal "https://ingest.obtrace.ai", cfg.ingest_base_url
    assert_equal "svc", cfg.service_name
  end

  def test_defaults
    cfg = ObtraceSDK::Config.new(
      api_key: "k",
      service_name: "svc"
    )
    assert_equal "dev", cfg.env
    assert_equal "1.0.0", cfg.service_version
    assert_equal 5, cfg.request_timeout_sec
    assert_equal false, cfg.debug
    assert_equal false, cfg.validate_semantic_metrics
  end

  def test_optional_fields
    cfg = ObtraceSDK::Config.new(
      api_key: "k",
      service_name: "svc",
      tenant_id: "t1",
      project_id: "p1",
      app_id: "a1",
      env: "production",
      debug: true
    )
    assert_equal "t1", cfg.tenant_id
    assert_equal "p1", cfg.project_id
    assert_equal "a1", cfg.app_id
    assert_equal "production", cfg.env
    assert_equal true, cfg.debug
  end
end
