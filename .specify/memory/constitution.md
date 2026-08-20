<!--
Sync Impact Report
- Version change: template → 1.0.0
- Added principles: Strangler Fig Delivery; Enforced Layer Boundaries; Focused Cubits;
  Critical Payroll and Attendance Safety; Spec-Driven, Test-First Delivery
- Added sections: Architecture and Data Constraints; Delivery Workflow and Quality Gates
- Removed sections: none (initial ratification replaces unresolved template placeholders)
- Follow-up TODOs: none
-->
# Zawolf HR / ERP Constitution

## Core Principles

### I. Strangler Fig Delivery
New architecture MUST be introduced beside the live implementation under `core/` and
`features/<module>/`. Routing or an explicit feature switch MUST select the active implementation.
Legacy screens, services, models, and jobs MUST remain in place until the replacement has documented
behavioral parity, passing tests, and production verification. Code that is not actively being
replaced MUST NOT be moved to an archive merely for tidiness. This keeps the application shippable and
protects live HR, attendance, and payroll operations throughout migration.

### II. Enforced Layer Boundaries
Each migrated module MUST use `data`, `domain`, and `presentation` layers. Presentation MAY import its
feature's domain contracts and shared presentation-safe `core` APIs; it MUST NOT import the feature's
data layer, Firebase, Firestore, Dio, or other concrete infrastructure types. Domain code MUST remain
framework-independent. Firebase, HTTP, and local-database implementations MUST sit behind interfaces
owned by the domain or a lower-level core contract. CI MUST mechanically reject boundary violations.

### III. Focused Cubits
BLoC/Cubit is the only state-management pattern permitted in newly migrated feature code. A Cubit MUST
own one UI-state responsibility and MUST NOT perform persistence, conflict resolution, API calls, or
cross-feature orchestration. Cubit files over 300 non-generated lines require explicit manual review
and written justification; splitting by responsibility is the default response. Existing state
management remains until its owning vertical slice is migrated and verified.

### IV. Critical Payroll and Attendance Safety
Payroll-cycle and attendance/absence behavior are critical business rules. A plain-language spec,
verified against the running scripts and reviewed by the product owner, MUST exist before any adjacent
code is changed. Existing idempotency keys, cycle boundaries, approval timing, absence marking,
deduction allocation, notification writes, and recovery behavior MUST be characterized by tests before
refactoring. Production Firestore rules and destructive migrations require explicit owner approval and
a rollback plan.

### V. Spec-Driven, Test-First Delivery
Every feature MUST have one matching `specs/<feature>/` lifecycle: specification, reviewed plan,
reviewed tasks, then implementation. Implementation MUST follow red-green-refactor: write or identify
the failing characterization test, make the smallest change that passes, and refactor only while the
suite stays green. The team MUST stop for owner review after specification, plan, and task generation;
these stages MUST NOT be chained into implementation without approval.

## Architecture and Data Constraints

- New code follows Feature-First Clean Architecture under `lib/core/` and
  `lib/features/<module>/{data,domain,presentation}`.
- SQLite through Drift or Isar is the UI-facing source of truth for migrated offline-capable modules.
  Writes MUST enter local storage and an outbox before synchronization with Firestore.
- Synchronization operations MUST be idempotent. Payroll and attendance records MUST use a version,
  event log, or equivalent conflict token; silent last-write-wins resolution is forbidden.
- Every synchronized entity MUST expose `synced`, `pending`, or `conflict` status to presentation.
- Arabic RTL and desktop web behavior are first-class acceptance surfaces. Shared design tokens and
  accessible atomic widgets MUST be validated against real migrated screens.
- Hostinger is an integration runtime, not an alternate business database. Scheduled-job ownership
  MUST be documented from the repository's actual workflows and runtime configuration.

## Delivery Workflow and Quality Gates

1. Audit current behavior and dependencies before proposing a replacement.
2. Run `$speckit-specify`, obtain owner review, then run `$speckit-plan` and stop again.
3. Run `$speckit-tasks`, obtain owner review, then implement with Superpowers disciplines.
4. Keep changes PR-sized and independently reviewable. A feature migration MUST NOT be mixed with
   unrelated cleanup or another feature migration.
5. Before a phase or module is complete, `flutter analyze`, layer-boundary checks, and relevant unit,
   widget, integration, and Node tests MUST pass.
6. A replacement route MUST NOT become the default until parity evidence, migration behavior, and a
   rollback path are documented. Old code is deleted only in a separate reviewed retirement change.
7. Every PR checklist MUST flag Cubit size, direct infrastructure imports, missing feature specs,
   critical-business-rule impact, and any irreversible operation.

## Governance

This constitution governs architecture and delivery decisions for Zawolf HR / ERP. Amendments require
a documented rationale, semantic-version impact, and owner approval. MAJOR changes remove or redefine
a governing principle; MINOR changes add a principle or materially expand obligations; PATCH changes
clarify wording without changing obligations. Each review MUST verify compliance, and any exception
MUST be time-bounded, documented with risk and rollback details, and approved by the owner. The active
`AGENTS.md`, feature specs, and plans MAY add stricter guidance but MUST NOT weaken this constitution.

**Version**: 1.0.0 | **Ratified**: 2026-08-20 | **Last Amended**: 2026-08-20
