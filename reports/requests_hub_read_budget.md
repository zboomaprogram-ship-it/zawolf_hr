# Requests Hub Read Budget & Query Boundaries (Task C014)

## Architecture Seam
All request queries in `lib/features/request_workspace/` are channeled exclusively through:
1. `RequestRepositoryImpl` -> `RequestVisibilityRepositoryImpl` -> `FirestoreRequestVisibilityDataSource`
2. Single-document point lookups (`getDetail`) by explicit `collection` and `requestId`.
3. Deterministic point mutations (`approveRequest`, `rejectRequest`, `cancelRequest`) using `docRef.update()` with array-union audit history.

## Query Boundaries & Limits
- **Page Size Cap**: 20 records per page (`limit = 20`).
- **Cursor Paging**: Bounded cursor evaluation based on `(occurredAt, stableId)` composite sorting.
- **Zero Realtime Listeners**: Neither the queue nor the browse/history views create Firestore collection listeners (`.snapshots()`). All queries are one-shot bounded reads (`.get()`).
- **Stale-While-Refresh**: Refreshing lists preserves the previous items in UI while fetching the new batch, displaying a subtle linear progress bar at the top instead of destroying DOM elements or dropping scroll positions.

## Read Impact Estimate
- Opening Queue ("طلبات عليا"): Exactly 1 bounded batch read via visibility cache/source.
- Toggling Filters: Exactly 1 bounded batch read with pageSize = 20.
- Approving/Rejecting: Exactly 1 document write + serverTimestamp.
- Detail Pane opening: Exactly 1 single-document read (`.doc(requestId).get()`).
