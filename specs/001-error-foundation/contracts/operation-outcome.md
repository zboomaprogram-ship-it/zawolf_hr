# Internal Contract: Operation Outcome and Safe Failure Guidance

## Purpose

This internal public contract is the only error/outcome vocabulary an adopted feature may expose from its domain-facing boundary. It is provider-neutral and suitable for future Auth, attendance, payroll, requests, and workspace modules.

## Contract invariants

1. Every adopted operation returns a confirmed success or a structured failure.
2. A structured failure always has a category, outcome certainty, and recovery guidance.
3. `unknown` outcome certainty maps to `checkStatusBeforeRetry`; UI must not offer a blind repeat of a write-like operation.
4. User-facing Arabic content derives from structured data only. It must never contain provider exception codes/classes, raw request details, stack traces, tokens, credentials, employee identifiers, or authorization rules.
5. `diagnosticKey` and safe context are for authorized support correlation; presentation must not render them by default.

## Consumer contract

Feature domain/presentation consumers may branch on success versus failure, render safe Arabic guidance, expose a retry only for `retrySafely`, and navigate to status/history for `checkStatusBeforeRetry`.

Feature consumers may not inspect raw Firebase/HTTP/Firestore exceptions, concatenate provider error text into UI, turn an unknown write outcome into success, or automatically replay an unsafe operation.

## Producer contract

Future feature data adapters normalize concrete infrastructure errors before returning them upward. They own provider-specific mapping and select certainty conservatively when the operation stage cannot be proven.

## Compatibility

This contract is additive. Existing `userFacingError` callers and legacy flows remain outside it until a feature has an approved migration plan and parity evidence.
