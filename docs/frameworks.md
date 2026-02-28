# Frameworks

Rails/Rack baseline:

```ruby
require_relative "../lib/obtrace_sdk"

client = ObtraceSDK::Client.new(cfg)
use ObtraceSDK::Framework.rack_middleware(client, app)
```
