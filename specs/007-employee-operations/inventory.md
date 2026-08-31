# Phase 007 navigation and product inventory

## Current reviewed surfaces

- `lib/screens/required_update_screen.dart`: Arabic retry/update screen; Phase
  007 will replace only the retry state machine after its contract tests exist.
- `lib/screens/manager/requests_mgmt.dart`: request, deduction, and security
  review tabs. Security review is a dedicated restricted surface and must be
  gated in both navigation and server authorization.
- `lib/navigation/router.dart`: additive legacy route manifest. RTL back
  navigation must preserve browser/mobile behavior.

## Guardrails

- No screen may rely on a client role check as its only authorization check.
- Browser text selection, copy, Ctrl+F, and native directionality remain
  enabled. Custom sheet/workspace behavior must not disable them.
- Force-update failures must provide Arabic retry/recovery, never a permanent
  blocking spinner.
