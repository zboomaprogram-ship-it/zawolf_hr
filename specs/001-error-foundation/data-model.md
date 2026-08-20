# Data Model: Shared Error Foundation

## OperationResult<T>

An immutable discriminated result for an adopted operation.

| Variant | Required fields | Meaning |
|---|---|---|
| Confirmed success | `value` | The operation completed and its outcome is known. |
| Failure | `failure` | The operation was rejected, not completed, or its final status is unconfirmed. |

Validation rules: a result has exactly one variant; a failure carries no success value; callers inspect the variant rather than a message.

## AppFailure

An immutable, provider-neutral explanation of an unsuccessful or unconfirmed operation.

| Field | Type / allowed values | Rules |
|---|---|---|
| `category` | `FailureCategory` | Required. One of the categories below. |
| `recovery` | `RecoveryGuidance` | Required. Defines the safe next action. |
| `outcomeCertainty` | `confirmedNotCompleted` or `unknown` | Required for any write-like operation. `unknown` never permits blind retry. |
| `diagnosticKey` | Optional non-sensitive string | For authorized support correlation only; never displayed. |
| `context` | Optional safe key/value metadata | Must not include raw exceptions, credentials, tokens, employee IDs, Firestore paths, or authorization-rule details. |

## FailureCategory

| Category | Example recovery | Typical certainty |
|---|---|---|
| `access` | contact responsible team | confirmed not completed |
| `authenticationSession` | sign in again | confirmed not completed |
| `validation` | correct input | confirmed not completed |
| `connectivity` | retry safely or check status | depends on operation stage |
| `temporaryService` | retry safely or check status | depends on operation stage |
| `capacityQuota` | retry later/contact responsible team | confirmed unless write state is unknown |
| `conflictDuplicate` | do not retry/check current record | confirmed no duplicate created |
| `missingData` | verify selection/contact responsible team | confirmed not completed |
| `unexpected` | check status before retry/contact responsible team | unknown by default for writes |

## RecoveryGuidance

| Value | User behavior |
|---|---|
| `correctInput` | Change incomplete or invalid data and submit again. |
| `signInAgain` | Re-authenticate before repeating the action. |
| `retrySafely` | The caller confirmed no write was applied; retry may be offered. |
| `checkStatusBeforeRetry` | Verify status first; do not duplicate. |
| `contactResponsibleTeam` | No self-service retry is appropriate. |
| `doNotRetry` | A duplicate/conflict has a known outcome; use the existing record. |

## UserSafeFailureMessage

A pure mapping from `AppFailure` to Arabic display content. Its title and body must provide a next action without exposing diagnostics.

```text
external error (future data adapter)
  -> AppFailure(category, certainty, recovery)
  -> OperationResult.failure
  -> UserSafeFailureMessage
  -> presentation/Cubit (future pilot)
```

The first foundation delivery creates the first three layers only. Provider mapping and presentation integration are deferred.
