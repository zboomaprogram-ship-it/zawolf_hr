# Research: Shared Error Foundation

## Decision 1: Use a sealed generic operation result contract

**Decision**: Represent adopted operations as a confirmed success or structured failure using a pure Dart sealed/discriminated `OperationResult<T>`.

**Rationale**: Explicit branches prevent message parsing and work across future features without coupling core to Firebase, HTTP, Flutter, or state management.

**Alternatives considered**: Throwing provider exceptions to screens was rejected because raw details can reach users. `null`/booleans plus a message were rejected because category and retry safety get lost. A third-party result package was rejected because a small stable contract needs no dependency.

## Decision 2: Map external errors at feature data boundaries

**Decision**: Future Firebase, Firestore, HTTP, and local-storage exception mappers live in feature `data` adapters, not `lib/core/errors/`.

**Rationale**: This preserves the constitution's framework-independent core/domain and prevents infrastructure leakage into presentation.

**Alternatives considered**: Importing Firebase types in core and mapping exceptions in widgets were rejected because both weaken layer boundaries and duplicate security-sensitive decisions.

## Decision 3: Model retry safety explicitly

**Decision**: Recovery guidance includes `correctInput`, `signInAgain`, `retrySafely`, `checkStatusBeforeRetry`, `contactResponsibleTeam`, and `doNotRetry`.

**Rationale**: A disconnected write can have an unknown final status while validation is known not to change data. They must not produce the same retry behavior.

**Alternatives considered**: A single retry boolean cannot represent unsafe retry. Automatic retry was rejected because it can duplicate attendance, approvals, deductions, or requests.

## Decision 4: Centralize Arabic user-safe wording as a pure policy

**Decision**: One pure message policy maps only structured failures to Arabic content, including a conservative fallback.

**Rationale**: This produces consistent safe guidance and allows tests to prove provider codes, stacks, authorization details, and identifiers cannot be exposed.

**Alternatives considered**: Reusing every legacy string in the new contract and translating provider errors were rejected; neither guarantees safety. Legacy code stays unchanged until selected.

## Decision 5: Add no diagnostic persistence in this slice

**Decision**: The contract may carry a support-safe diagnostic key/context, but Phase 1 adds no Firestore writes, crash reporting, analytics, or log persistence.

**Rationale**: Persistence and retention require their own privacy, authorization, cost, and operational design. The foundation must not create hidden writes or quota impact.

**Alternatives considered**: Persisting every failure and retaining raw exception objects were rejected because they can amplify cost and expose sensitive details.

## Decision 6: Preserve legacy behavior until a reviewed pilot

**Decision**: Leave `lib/utils/user_facing_error.dart` and all current callers unchanged. The first consumer is a separately reviewed Auth vertical slice.

**Rationale**: This is the smallest Strangler Fig step and avoids an unbounded rewrite of live workflows.

**Alternatives considered**: Replacing all handlers or adding a global catch-all were rejected because they have a large blast radius and hide operation semantics.
