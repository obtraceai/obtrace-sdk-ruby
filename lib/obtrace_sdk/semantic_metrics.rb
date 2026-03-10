module ObtraceSDK
  module SemanticMetrics
    THROUGHPUT = "http_requests_total"
    ERROR_RATE = "http_5xx_total"
    LATENCY_P95 = "latency_p95"
    RUNTIME_CPU_UTILIZATION = "runtime.cpu.utilization"
    RUNTIME_MEMORY_USAGE = "runtime.memory.usage"
    RUNTIME_THREAD_COUNT = "runtime.thread.count"
    RUNTIME_GC_PAUSE = "runtime.gc.pause"
    RUNTIME_EVENTLOOP_LAG = "runtime.eventloop.lag"
    CLUSTER_CPU_UTILIZATION = "cluster.cpu.utilization"
    CLUSTER_MEMORY_USAGE = "cluster.memory.usage"
    CLUSTER_NODE_COUNT = "cluster.node.count"
    CLUSTER_POD_COUNT = "cluster.pod.count"
    DB_OPERATION_LATENCY = "db.operation.latency"
    DB_CLIENT_ERRORS = "db.client.errors"
    DB_CONNECTIONS_USAGE = "db.connections.usage"
    MESSAGING_CONSUMER_LAG = "messaging.consumer.lag"
    WEB_VITAL_LCP = "web.vital.lcp"
    WEB_VITAL_FCP = "web.vital.fcp"
    WEB_VITAL_INP = "web.vital.inp"
    WEB_VITAL_CLS = "web.vital.cls"
    WEB_VITAL_TTFB = "web.vital.ttfb"
    USER_ACTIONS = "obtrace.sim.web.react.actions"

    ALL = [
      THROUGHPUT,
      ERROR_RATE,
      LATENCY_P95,
      RUNTIME_CPU_UTILIZATION,
      RUNTIME_MEMORY_USAGE,
      RUNTIME_THREAD_COUNT,
      RUNTIME_GC_PAUSE,
      RUNTIME_EVENTLOOP_LAG,
      CLUSTER_CPU_UTILIZATION,
      CLUSTER_MEMORY_USAGE,
      CLUSTER_NODE_COUNT,
      CLUSTER_POD_COUNT,
      DB_OPERATION_LATENCY,
      DB_CLIENT_ERRORS,
      DB_CONNECTIONS_USAGE,
      MESSAGING_CONSUMER_LAG,
      WEB_VITAL_LCP,
      WEB_VITAL_FCP,
      WEB_VITAL_INP,
      WEB_VITAL_CLS,
      WEB_VITAL_TTFB,
      USER_ACTIONS
    ].freeze

    def self.semantic_metric?(name)
      ALL.include?(name)
    end
  end
end
