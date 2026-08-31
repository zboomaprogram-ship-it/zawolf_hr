# Phase 6 — Notifications (R3) Read-Budget & Pagination Report

**Scope**: T044–T046 (`specs/ui_redesign/tasks.md` Phase 6, R3)
**Spec**: `specs/ui_redesign/06_priority_redesigns_spec.md` §R3

## Pagination bounds

| Surface | Query | Bound |
|---|---|---|
| Notification center list | `notifications/{uid}/items orderBy createdAt desc limit(20)` + explicit `تحميل المزيد` via `startAfterDocument` | 20 reads per user action; no auto-paging loop |
| Background push listener | `where isRead == false limit(25)` snapshots (`notification_service.dart`) | bounded snapshot listener, unchanged |
| Mark-all-read fallback | batched `where isRead == false limit(400)` loop with commit between batches | batches of ≤400 writes+reads; terminates when a batch returns <400 |

## Redesign impact on reads

- The R3 redesign (sticky day captions via `SliverPersistentHeader`, skeleton
  loading, filter chips) is **presentation-only**: no new Firestore queries,
  listeners, or index requirements were introduced.
- Filter chips operate client-side over the already-loaded page(s).
- Mark-all remains idempotent: unread-only query + per-doc guard in the
  transaction path; repeated taps converge to zero extra work once all items
  are read.

## Badge count source

Unchanged: `users/{uid}.unreadNotifications`, decremented transactionally by
per-item reads and reset to 0 by mark-all. The screen redesign never writes
this field directly outside those existing paths.

## Verification notes

- Page size constant `_pageSize = 20`; `_hasMore = docs.length == pageSize`
  keeps load-more bounded and stops exactly at the last page.
- No unbounded `.snapshots()` or `.get()` without `limit` was added in this
  phase (verified against `test/firestore_query_guard_test.dart`).
