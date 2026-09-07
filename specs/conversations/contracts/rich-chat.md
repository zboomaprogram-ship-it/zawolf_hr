# Rich Chat API Specification: /conversations/v2

**Feature**: Zawolf Chat Upgrade  
**Location**: `specs/conversations/contracts/rich-chat.md`  
**Base Path**: `https://notification.zawolf.ai/conversations/v2`

---

## 1. Authentication & Common Headers

- **Authentication**: All requests require an `Authorization: Bearer <FirebaseIdToken>` header. Caller identity and roles are verified server-side against the token claims. Client-supplied identity or roles are never accepted.
- **Content-Type**: `application/json; charset=utf-8` for JSON endpoints; `application/octet-stream` for chunk uploads.
- **Idempotency**: All mutation requests (`POST`, `PUT`) must provide an `operationId` in the JSON body or via `X-Operation-Id` header. Replaying the same `operationId` by the same actor returns the original result idempotently without re-execution.
- **Concurrency Control**: Updates to versioned resources require `expectedRevision`. If the current version does not match, HTTP `409 Conflict` is returned with `{ "ok": false, "code": "conflict" }`.
- **CORS Handling**: Supports `GET, POST, PUT, OPTIONS` with allowed headers `Authorization, Content-Type, X-Upload-Offset, X-Operation-Id, If-Match`.

---

## 2. Capabilities & Channels

### 2.1 GET `/capabilities`
Returns the feature flag state and HR review privileges for the calling user.

**Response `200 OK`**:
```json
{
  "ok": true,
  "enabled": true,
  "canReview": true
}
```

### 2.2 GET `/channels?cursor={cursor}`
Lists accessible channels for the user (department, manager, and enrolled custom channels) with pagination.

**Response `200 OK`**:
```json
{
  "ok": true,
  "channels": [
    {
      "id": "dept-engineering",
      "name": "الهندسة البرمجية",
      "kind": "department",
      "memberUserIds": ["uid-1", "uid-2"],
      "canPost": true,
      "unreadCount": 3,
      "hrReadable": true
    }
  ],
  "nextCursor": "cursor-string"
}
```

### 2.3 GET `/users?q={query}&cursor={cursor}`
Bounded lookup of active colleagues for custom channel creation.

**Response `200 OK`**:
```json
{
  "ok": true,
  "users": [
    {
      "id": "uid-2",
      "name": "أحمد محمود",
      "department": "الهندسة"
    }
  ],
  "nextCursor": null
}
```

---

## 3. Channel Requests & Management

### 3.1 GET `/requests?cursor={cursor}`
Retrieves channel requests. Regular employees see their own submissions; HR reviewers see the full queue.

**Response `200 OK`**:
```json
{
  "ok": true,
  "requests": [
    {
      "id": "req-123",
      "name": "فريق التجهيز للفعالية",
      "reason": "تنسيق مهام المعرض السنوي",
      "requesterId": "uid-1",
      "memberUserIds": ["uid-1", "uid-2", "uid-3"],
      "status": "pending",
      "revision": 1,
      "rejectionReason": null,
      "conversationId": null
    }
  ],
  "nextCursor": null
}
```

### 3.2 POST `/requests`
Submits a new custom channel proposal.

**Request Body**:
```json
{
  "operationId": "d3b07384-d113-494b-9c8e-32b0e2714c71",
  "name": "فريق التجهيز للفعالية",
  "reason": "تنسيق مهام المعرض السنوي",
  "memberUserIds": ["uid-1", "uid-2", "uid-3"]
}
```
*Validation*: `memberUserIds` must contain between 2 and 100 entries (including requester).

**Response `200 OK`**:
```json
{
  "ok": true,
  "request": {
    "id": "req-123",
    "name": "فريق التجهيز للفعالية",
    "reason": "تنسيق مهام المعرض السنوي",
    "requesterId": "uid-1",
    "memberUserIds": ["uid-1", "uid-2", "uid-3"],
    "status": "pending",
    "revision": 1
  }
}
```

### 3.3 POST `/requests/{id}/review`
HR review decision (approve or reject) with optional modification of name or member list.

**Request Body**:
```json
{
  "operationId": "b59a9972-749e-4a6c-b3b4-f655b356391d",
  "decision": "approved",
  "name": "فريق المعرض السنوي 2026",
  "memberUserIds": ["uid-1", "uid-2", "uid-3", "uid-4"],
  "reason": "موافقة مع إضافة مسؤول الدعم اللوجستي",
  "expectedRevision": 1
}
```
*Note*: If `decision` is `"rejected"`, `reason` is required.

**Response `200 OK`**:
```json
{
  "ok": true,
  "request": {
    "id": "req-123",
    "status": "approved",
    "conversationId": "custom-uuid-456",
    "revision": 2
  }
}
```

---

## 4. Message History, Actions & Synchronization

### 4.1 GET `/channels/{id}/messages?before={messageId}&limit=50`
Paginates historical messages backward from a cursor.

**Response `200 OK`**:
```json
{
  "ok": true,
  "messages": [
    {
      "id": "msg-001",
      "conversationId": "dept-engineering",
      "senderUserId": "uid-1",
      "senderDisplayName": "طارق علي",
      "body": "تم الانتهاء من مراجعة الكود",
      "sentAt": "2026-09-06T10:00:00.000Z",
      "state": "sent",
      "attachmentResourceIds": [],
      "attachments": [],
      "replyToMessageId": null,
      "forwarded": false,
      "revision": 1,
      "editedAt": null,
      "deletedAt": null,
      "reactions": { "uid-2": "👍" }
    }
  ],
  "nextCursor": "msg-000",
  "changeCursor": "1694000000000",
  "readers": {
    "uid-2": {
      "messageId": "msg-001",
      "name": "أحمد محمود",
      "sentAt": "2026-09-06T10:00:00.000Z",
      "readAt": "2026-09-06T10:01:30.000Z"
    }
  },
  "typing": [],
  "canPost": true
}
```

### 4.2 GET `/channels/{id}/changes?after={changeCursor}&limit=100`
Monotonic incremental synchronization of channel events.

**Response `200 OK`**:
```json
{
  "ok": true,
  "messages": [],
  "readers": {},
  "typing": [],
  "changeCursor": "1694000050000",
  "hasMore": false,
  "canPost": true
}
```

### 4.3 POST `/channels/{id}/messages`
Sends a new message.

**Request Body**:
```json
{
  "operationId": "msg-uuid-999",
  "body": "مرفق تقرير الحضور الشهري",
  "attachmentResourceIds": ["upload-res-123"],
  "replyToMessageId": "msg-001"
}
```

**Response `200 OK`**: Returns the committed `RichMessage` object.

### 4.4 POST `/channels/{id}/messages/{messageId}/actions`
Executes message mutations: edit, delete, react, forward.

**Request Body (Edit)**:
```json
{
  "operationId": "op-edit-1",
  "action": "edit",
  "body": "النص المعدل بعد التصحيح",
  "expectedRevision": 1
}
```

**Request Body (Delete)**:
```json
{
  "operationId": "op-del-1",
  "action": "delete",
  "expectedRevision": 1
}
```

**Request Body (React)**:
```json
{
  "operationId": "op-react-1",
  "action": "react",
  "emoji": "❤️"
}
```

**Request Body (Forward)**:
```json
{
  "operationId": "op-fwd-1",
  "action": "forward",
  "destinationId": "dept-marketing"
}
```

### 4.5 GET `/channels/{id}/messages/{messageId}/audit`
HR-only endpoint retrieving historical message revisions. Returns `403 Forbidden` for non-HR callers.

**Response `200 OK`**:
```json
{
  "ok": true,
  "revisions": [
    {
      "revision": 1,
      "body": "النص الأصلي قبل التعديل",
      "editedAt": "2026-09-06T10:05:00.000Z",
      "editedBy": "uid-1"
    }
  ]
}
```

### 4.6 POST `/channels/{id}/read`
Updates user read position for active foreground rendered messages.

**Request Body**:
```json
{
  "messageId": "msg-001"
}
```

**Response `200 OK`**: Returns updated `readers` map.

### 4.7 POST `/channels/{id}/typing`
Updates typing presence state.

**Request Body**:
```json
{
  "typing": true
}
```

---

## 5. Resumable Chunked Transfers & Downloads

### 5.1 POST `/channels/{id}/uploads`
Initializes a resumable upload session.

**Request Body**:
```json
{
  "operationId": "upload-op-1",
  "fileName": "contract_draft.pdf",
  "mimeType": "application/pdf",
  "sizeBytes": 15728640,
  "kind": "file"
}
```
*Constraints*: `sizeBytes <= 26,214,400` (25 MiB).

**Response `200 OK`**:
```json
{
  "ok": true,
  "resourceId": "upload-res-123",
  "offset": 0,
  "status": "initialized"
}
```

### 5.2 GET `/channels/{id}/uploads/{resourceId}`
Checks the committed byte offset for upload resumption.

**Response `200 OK`**:
```json
{
  "ok": true,
  "resourceId": "upload-res-123",
  "offset": 4194304,
  "status": "uploading"
}
```

### 5.3 PUT `/channels/{id}/uploads/{resourceId}`
Transfers a binary chunk.
- **Headers**:
  - `Content-Type: application/octet-stream`
  - `X-Upload-Offset: 4194304`
  - `X-Operation-Id: chunk-uuid-4`
- **Body**: Raw chunk bytes (\(\le 1\text{ MiB}\)).

**Response `200 OK`**:
```json
{
  "ok": true,
  "resourceId": "upload-res-123",
  "offset": 5242880,
  "status": "uploading"
}
```

### 5.4 POST `/channels/{id}/uploads/{resourceId}/finalize`
Verifies byte integrity and generates the permanent attachment descriptor.

**Response `200 OK`**:
```json
{
  "ok": true,
  "attachment": {
    "resourceId": "upload-res-123",
    "fileName": "contract_draft.pdf",
    "mimeType": "application/pdf",
    "sizeBytes": 15728640,
    "kind": "file",
    "status": "ready"
  }
}
```

### 5.5 GET `/channels/{id}/attachments/{resourceId}/download`
Streams the protected binary content.
- Re-verifies channel authorization.
- Returns authenticated binary stream with `Content-Type` and RFC 5987 UTF-8 `Content-Disposition: attachment; filename*=UTF-8''contract_draft.pdf`.

---

## 6. Channel Search & Link Preview

### 6.1 GET `/channels/{id}/search?q={query}&cursor={cursor}`
Performs bounded channel search (max 200 rows per request).

**Response `200 OK`**:
```json
{
  "ok": true,
  "messages": [],
  "nextCursor": null,
  "complete": true
}
```

### 6.2 POST `/channels/{id}/preview`
Fetches SSRF-safe public URL metadata.

**Request Body**:
```json
{
  "url": "https://example.com/article"
}
```

**Response `200 OK`**:
```json
{
  "ok": true,
  "preview": {
    "url": "https://example.com/article",
    "title": "Example Article Title",
    "description": "Article summary...",
    "image": "https://example.com/thumb.png"
  }
}
```
