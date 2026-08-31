# Diagnostics, Assistant, and Conversation Contract

## Safe error envelope

```json
{"code":"request_unavailable","messageAr":"تعذر إتمام العملية الآن. يمكنك المحاولة لاحقاً.","retryable":true,"diagnosticRef":"diag_..."}
```

It excludes provider/Firebase names, secrets, URLs with secrets, traces, salary,
message bodies, and attachment content.

## Assistant

`POST /assistant/ask` accepts question and operation ID. The runtime resolves
the caller, uses authorized non-confidential Arabic guidance, and refuses HR,
payroll, disciplinary, or management decisions. External AI is disabled unless
the separate owner/provider/retention/budget guard is enabled.

## Conversations

`POST /conversations`, `/messages`, and `/attachments` verify membership and
operation ID. Attachments return only an opaque Workspace resource ID/status.
`GET /attachments/{resourceId}/download` rechecks membership and makes an
audited short-lived transfer; it never returns a public Drive URL.
