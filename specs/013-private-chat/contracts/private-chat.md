# Private Chat Contracts

All routes require the existing authenticated rich-chat session and the `conversations_rich_chat_v1` capability. Every response uses the established `{ ok, code }` envelope.

## `GET /conversations/v2/contact-departments`

Returns active departments that contain at least one contact eligible to the actor.

Response: `{ departments: [{ id, name, eligibleCount }] }`.

## `GET /conversations/v2/eligible-contacts?department={id}&cursor={cursor}`

Returns a bounded page of active, server-authorized contacts in the selected department. The department is required for the normal picker flow.

Response: `{ contacts: [{ id, name, department, eligibilityReason }], nextCursor }`.

## `GET /conversations/v2/eligible-contacts?section={manager|hr|admin|it}&cursor={cursor}`

Returns the relevant exception section. The server returns only contacts the actor may privately message.

Response: `{ contacts: [{ id, name, department, eligibilityReason }], nextCursor }`.

## `POST /conversations/v2/direct`

Creates or returns a direct conversation.

Request: `{ targetUserId, operationId }`.

Response: `{ conversation: { id, kind: "direct", name, participantUserIds, canPost, unreadCount, latestActivityAt, latestActivityId } }`.

Errors: `validation_failed`, `target_inactive`, `access_denied`, `operation_conflict`.

## `GET /conversations/v2/channels?section={direct|group}&cursor={cursor}`

Returns a bounded authorized inbox page ordered by `latestActivityAt` descending and stable `latestActivityId` descending. `section` is required for this new contract; the existing unqualified channels response remains compatible during migration.

Response: `{ channels: [...], nextCursor }`.

## Existing channel operations

`messages`, `attachments`, `read`, `typing`, `changes`, `search`, and `members` operate for `kind: direct` only when the actor is one of the two participants and remains eligible to read/post under the authoritative state. Media download rechecks the same channel access.
