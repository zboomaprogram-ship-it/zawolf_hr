# Implementation Plan: Shared Error Foundation

**Branch**: `001-error-foundation` | **Date**: 2026-08-20 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/001-error-foundation/spec.md`

**Note**: This template is filled in by the `$speckit-plan` command; its definition describes the execution workflow.

## Summary

Introduce a framework-independent, typed result and failure vocabulary under `lib/core/errors/`. The first delivery adds only the contract, Arabic-safe message policy, recovery guidance, and unit tests. It does not migrate a screen, alter legacy `userFacingError`, change a provider integration, or change attendance, payroll, requests, routing, or Firestore rules. A later, separately reviewed Auth vertical slice will adapt provider failures at the data boundary and consume this contract in a Cubit.

## Technical Context

**Language/Version**: Dart 3.9.2; Flutter 3.38.10.

**Primary Dependencies**: Flutter, `firebase_auth`, `cloud_firestore`, `http`, and Provider in legacy code. The foundation itself has no Flutter, Firebase, HTTP, or state-management dependency.

**Storage**: N/A for the foundation. Existing production data remains Firestore; no reads, writes, schemas, migrations, or rules are changed.

**Testing**: Flutter unit tests in `test/core/errors/`; existing `flutter analyze`, Flutter test suite, architecture guard, and Node tests remain required gates.

**Target Platform**: Android, iOS, and Flutter web/desktop web.

**Project Type**: Existing Flutter HR/ERP application with a Hostinger Node integration runtime.

**Performance Goals**: Constant-time, allocation-light result classification and message lookup; no network calls, listeners, storage access, or background work from the foundation.

**Constraints**: Arabic messages must be user-safe; raw provider text, exception classes, stack traces, credentials, employee identifiers, and security-rule details must never enter presentation through this contract. Write-like unknown outcomes must require status verification before retry.

**Scale/Scope**: One shared, additive core package and pure unit tests. First consumer is deferred to a future reviewed Auth slice; current legacy callers, including the roughly 54 `userFacingError` call sites, remain unchanged.

## Constitution Check

### Pre-design

| Principle / Gate | Result | Evidence / plan response |
|---|---|---|
| I. Strangler Fig Delivery | PASS | The change is additive in `lib/core/errors/`; no legacy service, screen, route, or data path is replaced. A later pilot is separately selected and switchable at the route/workflow boundary. |
| II. Enforced Layer Boundaries | PASS | Core contract is pure Dart. Provider exception mapping is deliberately outside `core` and will live in a future feature data adapter. No presentation or domain code is added in this slice. |
| III. Focused Cubits | PASS | No Cubit is introduced because this slice has no UI owner. The future Auth pilot must use a focused Cubit and not perform provider work directly. |
| IV. Critical Payroll and Attendance Safety | PASS | Payroll, attendance, absence, approval timing, and Firestore rules are out of scope and untouched. |
| V. Spec-Driven, Test-First Delivery | BLOCKED FOR IMPLEMENTATION | Spec is reviewed and this plan is now awaiting review. The repository-wide Flutter quality gate is already red (two failing existing tests), so implementation cannot start until those failures are corrected in a separate focused change and the full gate is green. |

### Post-design

The design remains compliant: `operation_result.dart`, `app_failure.dart`, and policy/value files are pure core code; mapping external provider errors and displaying UI messages are deferred to a later vertical slice. No exception to the constitution is requested. The implementation blocker remains the inherited red full-suite baseline, not a design violation.

## Project Structure

### Documentation (this feature)

```text
specs/001-error-foundation/
├── plan.md              # This file ($speckit-plan command output)
├── research.md          # Phase 0 output ($speckit-plan command)
├── data-model.md        # Phase 1 output ($speckit-plan command)
├── quickstart.md        # Phase 1 output ($speckit-plan command)
├── contracts/
│   └── operation-outcome.md
└── tasks.md             # Phase 2 output ($speckit-tasks command - NOT created by $speckit-plan)
```

### Source Code (repository root)
```text
lib/
├── core/
│   └── errors/
│       ├── app_failure.dart
│       ├── failure_category.dart
│       ├── operation_result.dart
│       ├── recovery_guidance.dart
│       └── user_safe_failure_message.dart
├── features/                # unchanged by this slice
└── utils/
    └── user_facing_error.dart # legacy compatibility, unchanged

test/
└── core/
    └── errors/
        ├── operation_result_test.dart
        └── user_safe_failure_message_test.dart
```

**Structure Decision**: Use the existing Flutter application as a single project. The foundation is deliberately placed in `lib/core/errors/` because it is a provider-neutral, presentation-safe contract shared by future features. It does not create a catch-all service or a second state-management path.

## Delivery Sequence

1. In a separate focused maintenance change, repair the two inherited failing Flutter tests and prove the full baseline is green; do not combine that repair with this feature.
2. Add pure value types for result state, failure category, and recovery guidance using a sealed/discriminated contract.
3. Add the Arabic-safe message policy and a conservative fallback. It receives only structured failures, never external exception objects.
4. Add characterization/unit tests for all categories, messages, safe retry behavior, unknown outcomes, duplicates, and absence of raw technical text.
5. Run the complete quality gate. Then select the Auth pilot in a separate spec/plan/tasks cycle; its data adapter maps Firebase/Auth failures to this foundation and its Cubit owns only presentation state.

## Complexity Tracking

No constitution violations or complexity exceptions are required.
