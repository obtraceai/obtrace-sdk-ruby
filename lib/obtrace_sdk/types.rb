module ObtraceSDK
  class Config
    attr_accessor :api_key, :ingest_base_url, :tenant_id, :project_id, :app_id, :env
    attr_accessor :service_name, :service_version, :max_queue_size, :request_timeout_sec
    attr_accessor :default_headers, :debug

    def initialize(api_key:, ingest_base_url:, service_name:, tenant_id: nil, project_id: nil, app_id: nil, env: "dev", service_version: "1.0.0", max_queue_size: 1000, request_timeout_sec: 5, default_headers: {}, debug: false)
      @api_key = api_key
      @ingest_base_url = ingest_base_url
      @tenant_id = tenant_id
      @project_id = project_id
      @app_id = app_id
      @env = env
      @service_name = service_name
      @service_version = service_version
      @max_queue_size = max_queue_size
      @request_timeout_sec = request_timeout_sec
      @default_headers = default_headers
      @debug = debug
    end
  end
end
