# Data Model: Governed Private Chat

## Direct Conversation

| Field | Meaning | Validation |
|---|---|---|
| `id` | Deterministic direct conversation identifier | Stable for the sorted participant pair |
| `kind` | Conversation category | Exactly `direct` |
| `participantUserIds` | The two participants | Exactly two distinct active user IDs at creation; immutable thereafter |
| `pairKey` | Canonical participant pair | Derived from sorted IDs; unique |
| `state` | Availability | `active` or `closed` |
| `latestActivityAt` | Last visible message-related activity | Server-owned; used for ordering |
| `latestActivityId` | Stable order tie-breaker | Server-owned |
| `changeSequence` | Incremental synchronization position | Monotonic |
| `createdAt`, `updatedAt` | Audit timing | Server timestamps |

## Eligible Contact

| Field | Meaning |
|---|---|
| `id` | Active user ID |
| `name` | Display name |
| `department` | Current department |
| `eligibilityReason` | `ordinary_employee`, `assigned_manager`, `same_department_manager`, `hr`, `super_admin`, `it`, or `manager_override` |

The reason is display-safe metadata only. The server repeats eligibility evaluation for every mutation.

## Inbox Page

| Field | Meaning |
|---|---|
| `section` | `direct` or `group` |
| `items` | Authorized conversations in that section |
| `nextCursor` | Opaque activity cursor |
| `unreadCount` | Current actor’s unread messages |

## State and lifecycle

1. An actor asks for eligible contacts after choosing a department or shortcut section.
2. An actor starts a direct chat with a target user; the server checks eligibility, then creates or returns the deterministic direct conversation.
3. Message operations update latest activity and channel changes atomically.
4. Deactivation disables new selection and posting. Existing history follows the retained-history policy in the specification.
