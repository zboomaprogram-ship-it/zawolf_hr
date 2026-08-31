# Company OS

Phase 005 is an additive, disabled-by-default set of vertical slices. The
existing HR, request, payroll, attendance, notification, and attachment routes
remain the production fallback until each slice has independent pilot evidence
and explicit owner approval.

Layer ownership:

- `domain/` owns framework-independent entities, repository contracts, and use
  cases.
- `data/` owns HTTP, local persistence, DTO mapping, and concrete repository
  implementations.
- `presentation/` owns focused Cubits and Arabic RTL pages/widgets. It may only
  import the domain layer and presentation-safe core APIs.

The Hostinger runtime is an authenticated operation gateway. Firestore remains
the canonical remote business store; Hostinger is never a second database.
Google Workspace is optional through an attachment-reference contract and is
not required for Company OS to work.

