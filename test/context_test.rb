$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "minitest/autorun"
require "obtrace_sdk"

class ContextTest < Minitest::Test
  def test_ensure_propagation_headers_uses_provided_ids
    headers = ObtraceSDK::Context.ensure_propagation_headers(
      {},
      trace_id: "0123456789abcdef0123456789abcdef",
      span_id: "0123456789abcdef",
      session_id: "sess-1"
    )
    assert_equal "00-0123456789abcdef0123456789abcdef-0123456789abcdef-01", headers["traceparent"]
    assert_equal "sess-1", headers["x-obtrace-session-id"]
  end

  def test_ensure_propagation_headers_preserves_existing_traceparent
    headers = ObtraceSDK::Context.ensure_propagation_headers(
      { "traceparent" => "00-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-bbbbbbbbbbbbbbbb-01" },
      trace_id: "0123456789abcdef0123456789abcdef",
      span_id: "0123456789abcdef"
    )
    assert_equal "00-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-bbbbbbbbbbbbbbbb-01", headers["traceparent"]
  end
end
