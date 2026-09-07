# Data Model Specification: Zawolf Chat Upgrade (Rich Chat V1)

**Feature**: Zawolf Chat Upgrade  
**Location**: `specs/conversations/data-model.md`  
**Governing Standard**: `specs/conversations/spec.md`, `.specify/memory/constitution.md`

---

## 1. Remote Firestore Schema

Firestore serves as the authoritative remote store. All security rules enforce role-based and channel-membership-based read and write access.

### 1.1 Collection: `/conversations/{conversationId}`
Represents a communication channel (department, manager, or approved custom channel).

```typescript
interface FirestoreConversation {
  id: string;                      // Unique channel identifier (e.g., "dept-engineering", "custom-uuid")
  name: string;                    // Arabic display name
  kind: 'department' | 'manager' | 'custom';
  purposeAr?: string;              // Optional descriptive purpose
  memberUserIds: string[];         // UIDs of enrolled participants
  hrReadable: boolean;             // True if HR has nonmember inspection entitlement
  createdBy?: string;              // UID of creator (for custom channels)
  createdAt: FirebaseFirestore.Timestamp;
  updatedAt: FirebaseFirestore.Timestamp;
  lastMessageSnippet?: string;     // Preview for inbox list
  lastMessageAt?: FirebaseFirestore.Timestamp;
}
```

### 1.2 Subcollection: `/conversations/{conversationId}/messages/{messageId}`
Individual message records.

```typescript
interface FirestoreMessage {
  id: string;                      // Stable UUIDv4 operationId
  conversationId: string;
  senderUserId: string;            // Firebase Auth UID
  senderDisplayName: string;       // Display name at time of sending
  body: string;                    // Up to 4,000 UTF-8 characters (or empty if attachments present)
  sentAt: FirebaseFirestore.Timestamp; // Server acceptance timestamp (anchors 15-min edit window)
  state: 'sent' | 'edited' | 'deleted';
  attachmentResourceIds: string[]; // List of linked upload resource IDs
  attachments: FirestoreAttachmentDescriptor[];
  replyToMessageId?: string | null;// References parent message ID
  forwarded: boolean;              // True if forwarded from another channel
  revision: number;                // Integer sequence: 1 initial, increments on edit
  editedAt?: FirebaseFirestore.Timestamp | null;
  deletedAt?: FirebaseFirestore.Timestamp | null;
  reactions: Record<string, string>; // Map of UID -> emoji character (e.g. { "uid123": "👍" })
}
```

### 1.3 Subcollection: `/conversations/{conversationId}/messages/{messageId}/revisions/{revId}`
Immutable HR audit log for message edits and deletions.

```typescript
interface FirestoreMessageRevision {
  revision: number;
  body: string;
  editedAt: FirebaseFirestore.Timestamp;
  editedBy: string;                // Must match senderUserId
}
```

### 1.4 Subcollection: `/conversations/{conversationId}/readers/{userId}`
Per-user read positions for unread counts and group read receipts.

```typescript
interface FirestoreReaderPosition {
  userId: string;
  name: string;
  messageId: string;               // Highest seen message ID
  sentAt: FirebaseFirestore.Timestamp; // sentAt of the highest seen message
  readAt: FirebaseFirestore.Timestamp; // Timestamp when rendered in foreground
}
```

### 1.5 Subcollection: `/conversations/{conversationId}/typing/{userId}`
Ephemeral presence indicator.

```typescript
interface FirestoreTypingIndicator {
  userId: string;
  name: string;
  expiresAt: FirebaseFirestore.Timestamp; // TTL: 10 seconds from write
}
```

### 1.6 Collection: `/channel_requests/{requestId}`
Employee custom channel requests awaiting HR review.

```typescript
interface FirestoreChannelRequest {
  id: string;                      // UUIDv4 request identifier
  name: string;                    // Proposed channel name
  reason: string;                  // Business justification
  requesterId: string;             // UID of submitting employee
  requesterName: string;           // Name of employee
  memberUserIds: string[];         // 2 to 100 UIDs (must include requesterId)
  status: 'pending' | 'approved' | 'rejected';
  revision: number;                // Monotonic version for conflict detection
  rejectionReason?: string | null; // Mandatory if rejected
  conversationId?: string | null;  // Linked channel ID created on approval
  createdAt: FirebaseFirestore.Timestamp;
  reviewedAt?: FirebaseFirestore.Timestamp | null;
  reviewedBy?: string | null;      // UID of HR reviewer
}
```

### 1.7 Collection: `/conversation_uploads/{resourceId}`
Tracks state of chunked resumable transfers.

```typescript
interface FirestoreUploadSession {
  resourceId: string;              // UUIDv4 upload identifier
  channelId: string;
  userId: string;                  // Uploader UID
  fileName: string;
  mimeType: string;
  sizeBytes: number;               // Up to 26,214,400 bytes (25 MiB)
  kind: 'image' | 'video' | 'audio' | 'voice' | 'file';
  driveFileId: string;             // Pre-generated Google Drive file ID
  offset: number;                  // Bytes received so far (sequential 1 MiB chunks)
  status: 'initialized' | 'uploading' | 'completed' | 'failed';
  createdAt: FirebaseFirestore.Timestamp;
  updatedAt: FirebaseFirestore.Timestamp;
}
```

---

## 2. Local Drift Relational Database Schema (`ChatDatabase`)

The client maintains an offline-first, relational local database scoped by authenticated user UID.

### 2.1 Table: `LocalMessages`
Stores synchronized and optimistically pending messages.
- `id` (Text, Primary Key): Stable UUID message ID.
- `conversationId` (Text, Indexed): Channel ID.
- `senderUserId` (Text): Uploader UID.
- `senderDisplayName` (Text): Sender name.
- `body` (Text): Message text.
- `sentAt` (DateTime): Server or local creation timestamp.
- `state` (Text): `'pending'`, `'sent'`, `'failed'`, `'edited'`, `'deleted'`.
- `replyToMessageId` (Text, Nullable): Parent message reference.
- `forwarded` (Bool): Forwarding flag.
- `revision` (Integer): Message revision.
- `editedAt` (DateTime, Nullable).
- `deletedAt` (DateTime, Nullable).
- `reactionsJson` (Text): Serialized JSON map of reactions.
- `attachmentsJson` (Text): Serialized JSON list of attachment descriptors.
- `rawPayload` (Text, Nullable): Diagnostic backup payload.

### 2.2 Table: `LocalDrafts`
Stores uncommitted text and reply context per channel.
- `conversationId` (Text, Primary Key): Channel ID.
- `body` (Text): Composed draft text.
- `replyToMessageId` (Text, Nullable): Targeted reply message ID.
- `updatedAt` (DateTime): Last modification time.

### 2.3 Table: `LocalDraftFiles`
Stores attached files persistently before upload completes.
- `id` (Text, Primary Key): UUID draft file ID.
- `conversationId` (Text, Indexed): Target channel.
- `fileName` (Text): Original filename.
- `mimeType` (Text): Validated MIME type.
- `kind` (Text): Media kind (`image`, `voice`, `video`, `file`).
- `sizeBytes` (Integer): File size.
- `bytes` (Blob): Raw binary file bytes (durable local copy).
- `durationSeconds` (Real, Nullable): Audio/video duration.
- `width` (Integer, Nullable): Image width.
- `height` (Integer, Nullable): Image height.
- `createdAt` (DateTime).

### 2.4 Table: `LocalPendingOperations`
Reliable outbox for network mutations.
- `operationId` (Text, Primary Key): Stable UUIDv4.
- `conversationId` (Text, Indexed): Target channel.
- `kind` (Text): `'send_message'`, `'upload_chunk'`, `'edit_message'`, `'delete_message'`, `'react'`, `'read'`.
- `payloadJson` (Text): Serialized operation parameters.
- `status` (Text): `'queued'`, `'in_flight'`, `'failed'`.
- `retryCount` (Integer): Exponential backoff counter.
- `createdAt` (DateTime).

### 2.5 Table: `LocalReadPositions`
Caches the last read position per user.
- `conversationId` (Text): Channel ID.
- `userId` (Text): Member UID.
- `messageId` (Text): Highest message ID read.
- `readAt` (DateTime): Timestamp read.
- *Primary Key*: `(conversationId, userId)`.

### 2.6 Table: `LocalChannels`
Caches available channel list and badges.
- `id` (Text, Primary Key): Channel ID.
- `name` (Text): Channel name.
- `kind` (Text): Channel kind.
- `memberUserIdsJson` (Text): Serialized JSON array of members.
- `unreadCount` (Integer): Computed unread count.
- `canPost` (Bool): User posting permission.
- `hrReadable` (Bool): Nonmember HR inspection flag.
- `updatedAt` (DateTime).

---

## 3. Core Dart Domain Entities

Located in `lib/features/conversations/domain/entities/`:

```dart
class RichChannel {
  final String id;
  final String name;
  final String kind;
  final List<String> memberUserIds;
  final bool canPost;
  final int unreadCount;
  final bool hrReadable;
  const RichChannel({
    required this.id,
    required this.name,
    required this.kind,
    this.memberUserIds = const [],
    this.canPost = true,
    this.unreadCount = 0,
    this.hrReadable = false,
  });
}

class RichAttachment {
  final String resourceId;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final String kind;
  final int? width;
  final int? height;
  final double? durationSeconds;
  final String status;
  const RichAttachment({
    required this.resourceId,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.kind,
    this.width,
    this.height,
    this.durationSeconds,
    this.status = 'ready',
  });
}

class RichMessage {
  final String id;
  final String conversationId;
  final String senderUserId;
  final String senderDisplayName;
  final String body;
  final DateTime sentAt;
  final String state; // pending | sent | failed | edited | deleted
  final List<String> attachmentResourceIds;
  final List<RichAttachment> attachments;
  final String? replyToMessageId;
  final bool forwarded;
  final int revision;
  final DateTime? editedAt;
  final DateTime? deletedAt;
  final Map<String, String> reactions; // userId -> emoji
  const RichMessage({
    required this.id,
    required this.conversationId,
    required this.senderUserId,
    required this.senderDisplayName,
    required this.body,
    required this.sentAt,
    this.state = 'sent',
    this.attachmentResourceIds = const [],
    this.attachments = const [],
    this.replyToMessageId,
    this.forwarded = false,
    this.revision = 1,
    this.editedAt,
    this.deletedAt,
    this.reactions = const {},
  });
}

class ChatDraftFile {
  final String fileName;
  final String mimeType;
  final Uint8List bytes;
  final String kind;
  final double? durationSeconds;
  const ChatDraftFile({
    required this.fileName,
    required this.mimeType,
    required this.bytes,
    required this.kind,
    this.durationSeconds,
  });
}

class ChannelRequest {
  final String id;
  final String name;
  final String reason;
  final String requesterId;
  final List<String> memberUserIds;
  final String status; // pending | approved | rejected
  final int revision;
  final String? rejectionReason;
  final String? conversationId;
  const ChannelRequest({
    required this.id,
    required this.name,
    required this.reason,
    required this.requesterId,
    required this.memberUserIds,
    this.status = 'pending',
    this.revision = 1,
    this.rejectionReason,
    this.conversationId,
  });
}
```
