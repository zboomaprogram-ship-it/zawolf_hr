# Data Model: Chat Performance & High-Speed Asset Pipeline

## 1. Domain Entities

### `ChatDraftFile` (Expanded)
```dart
class ChatDraftFile {
  final String fileName;
  final String mimeType;
  final Uint8List bytes;
  final String? localFilePath;     // Path on device filesystem (when persisted)
  final String kind;               // 'image', 'video', 'voice', 'file', 'pdf'
  final double? durationSeconds;   // For audio/video
  final String? thumbnailBase64;   // Lightweight base64 thumbnail (< 10 KB)
  final int? sizeBytes;
}
```

### `RichAttachment` (Expanded)
```dart
class RichAttachment {
  final String resourceId;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final String kind;
  final double? durationSeconds;
  final String status;             // 'pending', 'uploaded', 'failed'
  final String? thumbnailBase64;   // Pre-generated micro-thumbnail
  final String? downloadUrl;       // Optional direct signed download URL
}
```

---

## 2. Local Storage Schema (Drift / Filesystem)

### Local Filesystem Directory Structure
```text
<ApplicationCacheDirectory>/
└── chat_cache/
    ├── outbox/                  # Unsent attachment blobs awaiting upload
    │   └── draft-{operationId}-{index}.bin
    ├── media/                   # Downloaded attachments (LRU managed)
    │   └── {actorId}-{channelId}-{resourceId}.bin
    └── thumbs/                  # Cached local thumbnails
        └── {resourceId}.thumb
```

### Drift SQLite Table: `ChatLocalMedia` (Replaces `ChatBlobRows`)
```sql
CREATE TABLE chat_local_media (
  actor TEXT NOT NULL,
  channel TEXT NOT NULL,
  resource_id TEXT NOT NULL,
  file_path TEXT NOT NULL,
  file_name TEXT NOT NULL,
  mime_type TEXT NOT NULL,
  size_bytes INTEGER NOT NULL,
  kind TEXT NOT NULL,
  duration_seconds REAL,
  created_at TEXT NOT NULL,
  last_accessed_at TEXT NOT NULL,
  PRIMARY KEY (actor, channel, resource_id)
);

CREATE INDEX idx_chat_media_lru ON chat_local_media (actor, last_accessed_at);
```

---

## 3. Server-Side Data Models (`conversationAttachments` in Firestore)

```typescript
interface ConversationAttachmentDoc {
  conversationId: string;
  uploaderUserId: string;
  operationId: string;
  fileName: string;
  mimeType: string;
  validatedMimeType?: string;
  sizeBytes: number;
  kind?: string;
  durationSeconds?: number;
  thumbnailBase64?: string;       // Inlined micro-thumbnail
  status: 'pending' | 'uploaded';
  offset: number;
  provider: 'firebase_storage' | 'google_workspace' | 'local';
  sessionUri?: string;            // Direct GCS resumable upload URI
  createdAt: Date;
  uploadedAt?: Date;
}
```
