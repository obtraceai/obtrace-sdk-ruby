# Security

- Send `Authorization: Bearer <api_key>`.
- Never place raw secrets in custom attributes.
- Keep SDK in fail-open mode; telemetry failures must not break app flow.
