$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "minitest/autorun"
require "obtrace_sdk"

class SemanticMetricsTest < Minitest::Test
  def test_exposes_canonical_metric_names
    assert_equal "runtime.cpu.utilization", ObtraceSDK::SemanticMetrics::RUNTIME_CPU_UTILIZATION
    assert_equal "db.operation.latency", ObtraceSDK::SemanticMetrics::DB_OPERATION_LATENCY
    assert_equal "web.vital.inp", ObtraceSDK::SemanticMetrics::WEB_VITAL_INP
  end
end
