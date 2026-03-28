require "logger"

module ObtraceSDK
  module LoggerCapture
    @client = nil
    @installed = false

    SEVERITY_MAP = {
      0 => "debug",
      1 => "info",
      2 => "warn",
      3 => "error",
      4 => "fatal",
      5 => "unknown"
    }.freeze

    module_function

    def install(client)
      return if @installed
      @client = client
      @installed = true

      ::Logger.prepend(LoggerPatch)
    end

    def client
      @client
    end

    def installed?
      @installed
    end

    def reset!
      @client = nil
      @installed = false
    end

    module LoggerPatch
      def add(severity, message = nil, progname = nil, &block)
        result = super

        client = ObtraceSDK::LoggerCapture.client
        if client
          if message.nil?
            if block
              msg = block.call
            else
              msg = progname
            end
          else
            msg = message
          end

          if msg && !msg.to_s.empty?
            level = ObtraceSDK::LoggerCapture::SEVERITY_MAP[severity] || "unknown"
            attrs = { "auto.source" => "logger_capture" }
            attrs["logger.progname"] = progname.to_s if progname && message
            client.log(level, msg.to_s, attrs)
          end
        end

        result
      end
    end
  end
end
