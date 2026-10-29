# Feature Specification: Request Workspace (Unified Requests Hub)

## Governing Architecture
This feature conforms to `.specify/memory/constitution.md` and `AGENTS.md`. It consolidates the 18 legacy request screens into a single, cohesive Requests Hub vertical slice.

## Structure
```text
lib/features/request_workspace/
  domain/
    entities/
      request_record.dart
    repositories/
      request_repository.dart
  data/
    request_repository_impl.dart
  presentation/
    cubits/
      request_queue_cubit.dart
      request_browse_cubit.dart
      request_detail_cubit.dart
    pages/
      requests_hub_page.dart
      request_detail_page.dart
specs/request_workspace/
  spec.md
```

## Architectural Boundaries
1. **Domain**: Pure Dart models (`RequestRecord`, `RequestTimelineEvent`) and repository interface (`RequestRepository`). Zero Flutter, Firebase, or Dio imports.
2. **Data**: `RequestRepositoryImpl` bridges queries onto the bounded `RequestVisibilityRepository` and performs deterministic updates for approvals/rejections with array-union history.
3. **Presentation**: Depends exclusively on domain contracts. All state management uses focused Cubits strictly under 300 lines (`RequestQueueCubit`: 166 lines, `RequestBrowseCubit`: 197 lines, `RequestDetailCubit`: 202 lines).
4. **Design System & Feedback**: Uses design system tokens (`ZaWolfColors`, `DsRadius`, `DsSpacing`), `StaleWhileRefresh` for pull-to-refresh, `SkeletonList` for shape-accurate loading, `EmptyState` and `ErrorState` for feedback, and `showConfirmationSheet` for approval and rejection modals.
