require "obtrace_sdk"

module ObtraceSDK
  class Railtie < ::Rails::Railtie
    initializer "obtrace_sdk.configure" do |app|
      api_key = credentials_fetch("obtrace_api_key") || ENV["OBTRACE_API_KEY"]
      ingest_url = credentials_fetch("obtrace_ingest_url") || ENV["OBTRACE_INGEST_BASE_URL"] || "https://inject.obtrace.ai"
      service_name = credentials_fetch("obtrace_service_name") || ENV["OBTRACE_SERVICE_NAME"] || ::Rails.application.class.module_parent_name.underscore rescue "rails-app"

      next unless api_key

      cfg = ObtraceSDK::Config.new(
        api_key: api_key,
        ingest_base_url: ingest_url,
        service_name: service_name,
        env: ::Rails.env.to_s,
        tenant_id: credentials_fetch("obtrace_tenant_id") || ENV["OBTRACE_TENANT_ID"],
        project_id: credentials_fetch("obtrace_project_id") || ENV["OBTRACE_PROJECT_ID"],
        app_id: credentials_fetch("obtrace_app_id") || ENV["OBTRACE_APP_ID"],
        debug: ENV["OBTRACE_DEBUG"] == "true"
      )

      client = ObtraceSDK::Client.new(cfg)
      ObtraceSDK.instance_variable_set(:@rails_client, client)

      app.middleware.insert(0, ObtraceSDK::Middleware, client)
    end

    def credentials_fetch(key)
      ::Rails.application.credentials.send(key) rescue nil
    end
  end

  def self.rails_client
    @rails_client
  end
end
