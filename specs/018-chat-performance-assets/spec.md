# Feature Specification: Chat Performance & High-Speed Asset Pipeline

**Feature Branch**: `018-chat-performance-assets`
**Created**: 2026-10-13
**Status**: Implemented
**Input**: "in chat feature i want you to analysis it and give me a plan to make it faster and the assets send fast and be stored" (Option A: End-to-end performance overhaul covering local file system storage, draft debouncing, client-side media compression, and direct cloud storage transfer).

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Smooth Composer Typing & Filesystem Blob Offloading (Priority: P1)

As an employee composing a chat message with multiple photo or document attachments,
I want my typing to remain completely fluid and instantaneous without keyboard stutter or lag,
so that drafting messages is fast and responsive regardless of how many large attachments are staged.

**Why this priority**: Currently, every single keystroke triggers an un-debounced rewrite of all staged attachment binary BLOBs directly into SQLite (`ChatBlobRows`). Typing with 3 attachments causes 15–300 MB of redundant SQLite writes per sentence, degrading the entire UI thread.

**Independent Test**: Can be tested independently on mobile and desktop web by picking 3 large files (>5 MB each), rapidly typing 50 characters in the composer, and verifying that zero binary BLOB writes occur during keystrokes and typing latency remains below 16 ms (60/120 fps).

**Acceptance Scenarios**:
1. **Given** 1 to 10 attachments staged in `ChatComposerCubit`, **When** the user types or edits text in the text field, **Then** text updates emit immediately without disk blocking, and draft text persistence is debounced by 800–1000 ms.
2. **Given** draft attachments already saved to disk, **When** text changes occur within the draft, **Then** existing binary file payloads on disk are NOT rewritten or duplicated.
3. **Given** staged attachments, **When** persisted locally, **Then** binary data is stored as isolated files in the app's sandboxed media cache directory (`chat_cache/`), and Drift/SQLite stores only metadata records (local path URI, file name, MIME type, byte size, duration).

---

### User Story 2 - Instant Client-Side Image Pre-Compression & Micro-Thumbnails (Priority: P1)

As an employee sending images or camera photos in chat,
I want my images to be compressed automatically before upload and to generate a lightweight micro-thumbnail,
so that uploads finish in a fraction of the time and the recipient immediately sees a preview.

**Why this priority**: Uncompressed mobile camera photos often exceed 6–12 MB each. Compressing them down to high-definition WebP/JPEG (max 1920px at 80% quality) reduces payload sizes by 85–92% (down to ~400–800 KB) before they even hit the network, creating an immediate 5x–10x speedup in upload time.

**Independent Test**: Can be tested independently by capturing an 8 MB camera photo, verifying client-side compression reduces it to < 800 KB within 150 ms, generating an inline Base64 thumbnail (< 10 KB), and verifying the message bubble displays the thumbnail instantaneously.

**Acceptance Scenarios**:
1. **Given** an image selected from the gallery or camera, **When** added to the composer, **Then** the client performs non-blocking background compression (max dimension 1920px, target quality 80%) before staging.
2. **Given** a compressed image, **When** staged for sending, **Then** a low-resolution micro-thumbnail (max 120px, < 10 KB) is generated and embedded in the message payload.
3. **Given** a message received with an embedded micro-thumbnail, **When** rendered in the chat timeline, **Then** the recipient immediately sees the blurred micro-thumbnail while the full asset downloads in the background.

---

### User Story 3 - High-Speed Direct Cloud Uploads (Priority: P2)

As an employee uploading attachments (videos, documents, voice notes, photos),
I want the upload to transfer directly to cloud object storage in high-throughput chunks,
so that upload speeds are maximized without bottlenecking through the application server.

**Why this priority**: Currently, uploads travel through a double-hop proxy (Client $\to$ Hostinger Node.js server $\to$ Google Cloud Storage) in 1 MiB chunks over sequential HTTP requests. Uploading directly to Google Cloud Storage (GCS) using 4 MiB chunks reduces latency and cuts server resource load.

**Independent Test**: Can be tested independently by uploading a 20 MB video, verifying that the client requests an upload session from the backend, receives a secure GCS Resumable Upload session URI, and pushes 4 MiB chunks directly to GCS with progressive upload feedback.

**Acceptance Scenarios**:
1. **Given** an authorized channel member initiating an upload, **When** calling `POST /conversations/v2/channels/{id}/uploads`, **Then** the server allocates the resource ID and returns a direct GCS Resumable Upload URL.
2. **Given** a valid direct upload session, **When** transferring chunks, **Then** the client uploads 4 MiB binary chunks directly to the GCS endpoint, reporting exact byte progress to the UI.
3. **Given** corporate firewall or network restrictions blocking direct GCS access, **When** direct chunk transfer fails with a network error, **Then** the client automatically falls back to the existing server-proxied upload route transparently.
4. **Given** all chunks uploaded, **When** client calls `POST /conversations/v2/channels/{id}/uploads/{resourceId}/finalize`, **Then** server verifies total file size and marks the attachment ready.

---

### User Story 4 - Filesystem Media Cache & Direct CDN Downloads (Priority: P2)

As an employee viewing received chat media,
I want images, voice notes, and documents to load instantly and be cached on device storage,
so that viewing media does not redownload from the network and does not bloat SQLite.

**Why this priority**: Currently, downloaded media files are written as BLOBs into SQLite up to a 256 MB cap. Moving persistent media caching to the local filesystem with an LRU policy ensures high-speed disk reads and prevents SQLite locking.

**Independent Test**: Can be tested independently by opening an image attachment, closing the app, restarting offline, and verifying that the image loads immediately from local disk cache without network requests.

**Acceptance Scenarios**:
1. **Given** an attachment download request, **When** fetching media, **Then** the server provides a signed download URL or streams with long-term cache headers (`Cache-Control: private, max-age=604800, immutable`).
2. **Given** downloaded bytes received, **When** saving locally, **Then** the file is saved directly to `chat_cache/{resourceId}` on the filesystem.
3. **Given** the local media cache exceeds the 256 MB budget, **When** a new file is added, **Then** the oldest unaccessed files are evicted from the filesystem using an LRU (Least Recently Used) policy.

---

## Edge Cases

- **Offline Draft Persistence**: If the device loses power or app is terminated mid-typing, the debounced text and already saved filesystem attachments must be restored cleanly on app relaunch.
- **Direct Cloud Upload Failure / CORS / Firewall**: If an enterprise network blocks direct connections to `*.googleapis.com`, the client must smoothly fall back to the Hostinger Node.js proxy without failing the user's upload.
- **Storage Permission & Disk Quota**: If the device filesystem is full or nearing quota, media caching must catch disk exceptions gracefully, notify the user, and evict stale cached assets before failing.
- **Migration of Existing SQLite Blobs**: On first launch with the new version, any legacy blobs remaining in `chat_blob_rows` are either lazily migrated to filesystem files upon access or dropped if orphaned, followed by an SQLite `VACUUM` to reclaim disk space.

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: `ChatComposerCubit` MUST debounce draft persistence by at least 800 ms during continuous typing.
- **FR-002**: `ChatComposerCubit` and `RichChatRepository` MUST NOT re-serialize or rewrite draft attachment files when only the message body text changes.
- **FR-003**: All binary attachment payloads MUST be stored in the platform application cache directory on the local filesystem rather than as SQLite BLOB table rows.
- **FR-004**: Drift / SQLite local storage MUST only maintain attachment metadata (local file path, size, MIME type, status, timestamps).
- **FR-005**: The client MUST compress images prior to staging when selected via gallery or camera (default: max dimension 1920px, WebP/JPEG quality 80%, strip heavy EXIF metadata).
- **FR-006**: Image attachments MUST generate a micro-thumbnail (max 120px dimension, $\le 10$ KB) embedded in the initial message payload for instantaneous recipient rendering.
- **FR-007**: The backend upload initialization endpoint (`POST /conversations/v2/channels/{id}/uploads`) MUST support returning a direct GCS Resumable Upload session URI when cloud storage is active.
- **FR-008**: The client upload manager MUST support uploading 4 MiB chunks directly to the cloud storage session URI.
- **FR-009**: The client upload manager MUST provide automatic fallback to server-proxied chunk uploads if direct cloud upload encounters network connectivity errors.
- **FR-010**: Downloaded chat media MUST be cached in the filesystem cache with an LRU budget capped at 256 MB.
- **FR-011**: Media downloads MUST use HTTP cache headers (`Cache-Control: private, max-age=604800, immutable`) to avoid redundant network round-trips.
- **FR-012**: The Strangler Fig migration MUST preserve full backward compatibility with legacy Drive and server-proxied attachments.

---

## Success Criteria *(mandatory)*

- **SC-001**: Typing latency in the composer with 3+ attachments remains under 16 ms (smooth 60 fps) with 0 MB of binary BLOB writes during active typing.
- **SC-002**: Average upload duration for standard camera photos (5–8 MB uncompressed) decreases by at least 70% (from ~5–8 seconds to under 1.5 seconds on a 20 Mbps mobile connection).
- **SC-003**: Timeline image preview display time drops to < 200 ms for new incoming images via micro-thumbnail embedding.
- **SC-004**: Drift / SQLite database file size remains stable (< 15 MB) regardless of how many multi-megabyte media attachments are sent or received.
- **SC-005**: 100% of failed direct-cloud uploads transparently fall back to the server-proxied route without showing an error to the user.
- **SC-006**: All existing unit tests and architecture guard tests (`test/architecture_guard_test.dart`, `test/firestore_query_guard_test.dart`, `scripts/test/rich-conversations.test.js`) continue to pass.

---

## Key Entities

- **`ChatDraftFile`**: Represents a local or cached file descriptor (`fileName`, `mimeType`, `bytes` or `filePath`, `sizeBytes`, `kind`, `thumbnailBytes`).
- **`LocalMediaRecord`**: Metadata stored in Drift for local attachments (`id`, `filePath`, `fileName`, `mimeType`, `sizeBytes`, `createdAt`, `lastAccessedAt`).
- **`AttachmentUploadSession`**: Encapsulates the active upload state (`resourceId`, `directUploadUrl`, `proxyUploadUrl`, `offset`, `totalBytes`, `chunkSize`).
- **`RichAttachment`**: The domain entity representing an uploaded and verified attachment, expanded with optional `thumbnailBase64` or `thumbnailUrl`.
