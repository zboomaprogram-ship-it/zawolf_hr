# Phase 007 Research Decisions

## Effective date anchors payroll

**Decision**: Attendance corrections and deduction views show approval and
submission dates, but group financial impact by the attendance/request execution
date and its Cairo payroll cycle.

**Rationale**: The payroll specification assigns permissions to `requestDate`,
not approval time. This avoids silently moving a late approved request into the
next cycle.

**Rejected**: approval-time grouping, because it changes the business result at
the 25/26 boundary.

## Bounded role-scoped query unions

**Decision**: Read each authorized collection/state with a bounded cursor,
merge by `(collection,id)`, sort by effective date, and expose explicit loading,
empty, error, and next-page state.

**Rationale**: Request/deduction history lives in several collections and
statuses. It prevents missing records, duplicate rows, and an unbounded global
listener.

**Rejected**: an unbounded collection-group listener for cost/rules/scale risk.

## Canonical unread notification count

**Decision**: Mark-all-read uses an idempotent operation ID, bounded server
pages, and a canonical unread-count projection. UI clears optimistically then
reconciles.

**Rejected**: counting all unread documents on every navigation build due to
read cost and write races.

## Recipient-role deep links

**Decision**: Notification payload carries opaque resource IDs; server resolves
the current recipient's authorized route. Approvers go to management context;
employees go to their own context; unavailable items fall back to authorized
list.

**Rejected**: trusting a stored employee route for every recipient.

## Reversible operational hiding

**Decision**: Add audited `operationalVisibility` (`included` or
`hidden_from_default_operational_views`) to reporting projections only.

**Rationale**: Test accounts disappear from daily operational counts while
remaining active, auditable, and recoverable.

**Rejected**: deactivate/delete because that corrupts account/history/payroll meaning.

## Server-owned sales mapping

**Decision**: Approved external identity → employee mapping lives in a
server-authorized registry. Unmatched/ambiguous rows remain unresolved; every
card/chart/list/export reads the same filter-versioned snapshot.

**Rejected**: name matching and client-side provider calls due to wrong
attribution and secret exposure. Rotate the shared test key before production.

## Provider-neutral governed assistant and conversations

**Decision**: Start with local approved Arabic guidance and a domain assistant
boundary. External AI stays disabled until provider, retention, regional
processing, caps, and budget are owner-approved. Conversation metadata is
governed in Firestore; binaries use the existing authorized Company Drive
adapter and no raw Drive URL is returned.

**Rejected**: direct free public AI and public Drive URLs due to data leakage,
uncontrolled cost, and no revocation/audit.

## Safe diagnostic aggregation

**Decision**: Persist only a sanitized `(release, feature, operation, safeCode,
fingerprint)` aggregate with count and timestamps. The user sees an Arabic
recovery state, never raw stack/provider/Firebase/token/content values.

**Rejected**: full exception storage because it risks sensitive content and an
unbounded event flood.

## WorkOutcome compatibility projection

**Decision**: Create one `WorkOutcome` linked to legacy task and optional KPI;
write compatible projection events while old history remains immutable/visible.

**Rejected**: replacing task/KPI collections in-place because it risks history
and report breakage.
