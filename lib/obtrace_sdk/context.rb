require "securerandom"

module ObtraceSDK
  module Context
    module_function

    def random_hex(bytes)
      SecureRandom.hex(bytes)
    end

    def ensure_propagation_headers(headers = {}, trace_id: nil, span_id: nil, session_id: nil)
      out = (headers || {}).dup
      out["traceparent"] ||= "00-#{trace_id || random_hex(16)}-#{span_id || random_hex(8)}-01"
      out["x-obtrace-session-id"] ||= session_id if session_id && !session_id.empty?
      out
    end
  end
end
