$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "minitest/autorun"
require "obtrace_sdk"
require "logger"
require "stringio"

class LoggerCaptureTest < Minitest::Test
  def setup
    ObtraceSDK::HttpInstrumentation.reset!
    ObtraceSDK::LoggerCapture.reset!
  end

  def make_client(auto_logs: true)
    cfg = ObtraceSDK::Config.new(
      api_key: "test-key",
      ingest_base_url: "http://localhost:19999",
      service_name: "test-svc",
      auto_instrument_http: false,
      auto_capture_logs: auto_logs
    )
    ObtraceSDK::Client.new(cfg)
  end

  def test_install_sets_installed
    client = make_client
    assert ObtraceSDK::LoggerCapture.installed?
    assert_equal client, ObtraceSDK::LoggerCapture.client
  end

  def test_skip_when_disabled
    _client = make_client(auto_logs: false)
    refute ObtraceSDK::LoggerCapture.installed?
  end

  def test_severity_map_covers_all_levels
    map = ObtraceSDK::LoggerCapture::SEVERITY_MAP
    assert_equal "debug", map[0]
    assert_equal "info", map[1]
    assert_equal "warn", map[2]
    assert_equal "error", map[3]
    assert_equal "fatal", map[4]
    assert_equal "unknown", map[5]
  end

  def test_logger_still_writes_output
    client = make_client
    io = StringIO.new
    logger = Logger.new(io)
    logger.info("hello from test")
    assert_includes io.string, "hello from test"
  end

  def test_logger_block_form
    client = make_client
    io = StringIO.new
    logger = Logger.new(io)
    logger.info { "block message" }
    assert_includes io.string, "block message"
  end

  def test_reset_clears_state
    _client = make_client
    assert ObtraceSDK::LoggerCapture.installed?
    ObtraceSDK::LoggerCapture.reset!
    refute ObtraceSDK::LoggerCapture.installed?
    assert_nil ObtraceSDK::LoggerCapture.client
  end
end
