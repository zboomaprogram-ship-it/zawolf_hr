# Phase Conversations: Architectural Research Decisions

**Feature**: Zawolf Chat Upgrade (Rich Chat V1)  
**Location**: `specs/conversations/research.md`  
**Governing Standard**: `.specify/memory/constitution.md`

---

## ADR 1: Drift Relational Database with WebAssembly Worker vs Browser Key-Value Stores

### Context
Offline drafts, multi-file attachments, message queues, and read positions require local durability across mobile, desktop, and web clients. Browser tabs are susceptible to memory eviction, background throttling, and quota pressure. Previous simple key-value stores (e.g., Hive or SharedPreferences) lack transactional atomicity, relational querying for search, and robust cross-platform schema migration support.

### Decision
Use a feature-owned **Drift** SQLite database (`lib/features/conversations/data/local/chat_database.dart`) with native SQLite on iOS, Android, and macOS, and the official Drift WebAssembly worker (`web/drift_worker.js`, `web/sqlite3.wasm`) with Origin Private File System (OPFS) or IndexedDB persistence on web.

### Rationale
1. **ACID Transactional Guarantees**: Inserting an outbox message and its multiple draft file records occurs in a single atomic transaction.
2. **Schema Evolution**: Drift provides robust, compile-time verified migrations as new chat primitives are introduced.
3. **Web Worker Offloading**: Moving query execution and file encoding off the main browser UI thread prevents frame drops during scrolling and media decoding.
4. **Transparent Quota Failure Handling**: When browser storage quota is exhausted, Drift raises explicit errors that the UI catches to display Arabic user alerts instead of silently losing drafts.

### Alternatives Considered & Rejected
- *Hive / Isar*: Inconsistent web support, lack of active maintenance, and lack of relational constraints.
- *Raw IndexedDB*: Cumbersome API requiring manual transaction lifecycle management; no shared codebase with native SQLite.

---

## ADR 2: 1 MiB Chunked Resumable Transfers to Google Drive via Hostinger Proxy vs Direct Client Drive API

### Context
Users upload files up to 25 MiB, often over unstable mobile data connections. Direct client uploads to Google Drive would require exposing OAuth2 client secrets, Drive service account tokens, or public Drive folder permissions to untrusted mobile clients. Furthermore, an upload can drop mid-stream, wasting bandwidth and battery if restarted from byte zero.

### Decision
Implement chat-specific resumable transfers in sequential 1 MiB binary chunks via the authenticated Hostinger proxy (`scripts/conversations/uploads.js`):
1. Client initializes session via `POST /channels/{id}/uploads`, providing metadata.
2. Server verifies channel authorization, creates an upload tracking document in `/conversation_uploads`, and pre-generates a unique Google Drive file ID.
3. Client transfers binary chunks via `PUT /channels/{id}/uploads/{resourceId}` with `X-Upload-Offset` and `X-Operation-Id` headers.
4. Server appends chunks to a private staging file or streams directly to the Drive resumable upload URI.
5. If interrupted, the client queries `GET /channels/{id}/uploads/{resourceId}` to retrieve the committed offset and resumes without data duplication.
6. Client calls `POST /channels/{id}/uploads/{resourceId}/finalize` to commit the file descriptor to the message record.

### Rationale
1. **Zero Secret Leakage**: Service account credentials remain secured on the Hostinger runtime.
2. **Deterministic Resumption**: The pre-generated Drive file ID prevents orphaned files if connection drops during finalization.
3. **Strict Authorization**: Every chunk and download request re-verifies channel membership against canonical Firestore security rules.
4. **No Public URLs**: Media is never accessible via unauthenticated public links; all downloads flow through authenticated streams.

### Alternatives Considered & Rejected
- *Firebase Storage Direct Uploads*: Requires configuring additional cloud infrastructure, incurring separate egress billing when Hostinger and Google Drive are already established company infrastructure.
- *Single-Request Multipart Form*: Fails frequently on large files over mobile connections; forces restarting 25 MiB transfers from scratch upon a single packet loss.

---

## ADR 3: 16 kHz Mono WAV Audio Recording vs Compressed AAC/Opus

### Context
Voice notes require reliable recording and playback across target client platforms:
- **Primary Web Targets**: Google Chrome and Brave (Chromium-based desktop browsers).
- **Mobile Targets**: iOS and Android.
- **Desktop Targets**: Linux, Windows, and macOS (future-ready cross-platform release).

Proprietary or containerized compressed codecs (e.g., AAC in MP4, Opus in OGG or WebM) have fragmented recording/playback implementations across native desktop and browser runtimes.

### Decision
Standardize on **16 kHz 16-bit Mono Linear PCM WAV** (`audio/wav`) using `record: ^6.2.1` via `ChatRecorderImpl`:
- Sample Rate: 16,000 Hz.
- Channels: 1 (Mono).
- Bit Depth: 16-bit signed integer PCM.
- Maximum Duration: 300 seconds (5 minutes), producing a maximum byte size of:
  \[
  16000 \times 2 \text{ bytes} \times 300 \text{ s} = 9,600,000 \text{ bytes } (\approx 9.15\text{ MiB})
  \]
  which fits well within the 25 MiB attachment limit.

### Rationale
1. **Universal Cross-Platform Playback**: Linear PCM WAV is natively decodable by Chromium browser audio engines (`HTMLAudioElement` / Web Audio API) in Chrome and Brave, as well as native audio players (`audioplayers`) across iOS, Android, Linux, Windows, and macOS with zero transcoding.
2. **Zero Server Dependency**: Eliminates the need for server-side FFmpeg transcoding on Hostinger, reducing CPU overhead and latency.
3. **Voice Clarity**: 16 kHz is the standard telecommunication wideband audio standard (G.722), delivering crisp human voice intelligibility.

### Alternatives Considered & Rejected
- *AAC in M4A*: Inconsistent recording stream support in browser environments.
- *Opus in WebM*: Unusable in older browser runtimes or native desktop players without client-side WebAssembly transcoders.

---

## ADR 4: 15-Minute Edit/Delete Window with Tombstones and HR Audit Trail vs Hard Deletes

### Context
Users occasionally make typographical errors or send messages to the wrong channel. However, in an enterprise HR/ERP system, employee communications can constitute evidence in disciplinary, attendance, or contractual disputes. Allowing arbitrary message deletion or unrecorded edits creates regulatory and accountability risks.

### Decision
Enforce a strict, server-validated **15-minute window** from message creation (`sentAt`) for sender-initiated edits and deletions:
1. **Sender Only**: Only the original `senderUserId` can edit or delete their message.
2. **Concurrency Detection**: Edits must pass `expectedRevision` matching the current message revision.
3. **Visible Tombstones**: Deleted messages remain visible in the chat timeline with the text `تم حذف هذه الرسالة` and a `deletedAt` timestamp.
4. **Immutable Audit History**: Prior revisions and deleted text are archived in `/conversations/{id}/messages/{messageId}/revisions` accessible exclusively to authorized HR/admin roles.

### Rationale
1. **Immediate Error Recovery**: Provides senders an adequate 15-minute window to fix typos or cancel accidental sends.
2. **Evidentiary Integrity**: Prevents retroactive alteration of agreements or communication history days or weeks later.
3. **Compliance Transparency**: Disclosing revision history to HR preserves workplace accountability while protecting everyday employee privacy.

### Alternatives Considered & Rejected
- *Permanent Hard Deletion*: Deleting the Firestore document destroys audit trails and leaves orphaned replies pointing to nonexistent parent IDs.
- *Uncapped Edit Window*: Allowing edits hours or days later disrupts conversational context and undermines trust.

---

## ADR 5: Bounded Lifecycle Synchronization vs Unbounded Real-Time Firestore Listeners

### Context
The legacy application used continuous full-collection listeners and frequent full-history re-fetching. In large department channels, this caused severe battery drain, high mobile data usage, and exceeded Firestore read budgets.

### Decision
Implement a single **lifecycle-owned synchronizer** using bounded HTTP/Firestore query windows:
1. **History Paging**: On initial channel open, fetch 50 messages using `before={cursor}`. Older pages load on-demand during upward scroll.
2. **Monotonic Change Cursor**: Active channels poll `/conversations/v2/channels/{id}/changes?after={changeCursor}&limit=100` every 3 seconds. The cursor tracks server mutation timestamps, returning only new messages, edits, tombstones, reactions, and read receipts.
3. **Inbox Polling**: Channel list updates every 15 seconds.
4. **Lifecycle Pause & Exponential Backoff**: When the app transitions to `paused` or `detached`, all polling immediately halts. Network errors trigger exponential backoff (3s \(\to\) 6s \(\to\) 12s \(\to\) 24s, capped at 60s).

### Rationale
1. **Predictable Read Budgets**: Active polling with monotonic cursors reads only documents that have actually changed since the last request.
2. **Zero Orphaned Listeners**: Clean lifecycle hooks (`WidgetsBindingObserver`) ensure no background leaks occur when users navigate away.
3. **Battery & Data Conservation**: Pausing during backgrounding eliminates idle data consumption.

### Alternatives Considered & Rejected
- *Global Firestore Snapshot Listeners*: Exposes the client to unbounded read cascades on active channels and complicates local outbox reconciliation.

---

## ADR 6: SSRF-Safe Public Link Preview Proxying

### Context
Rendering rich previews for URLs pasted in chat requires fetching target HTML pages to extract Open Graph (`og:title`, `og:image`, `og:description`) metadata. If performed naively by the server, an attacker could supply intranet URLs (e.g., `http://169.254.169.254/latest/meta-data/` or internal database endpoints), leading to Server-Side Request Forgery (SSRF).

### Decision
Implement link preview extraction on the Hostinger server (`scripts/conversations/previews.js`) with strict security constraints:
1. **Scheme Validation**: Strictly permit `http:` and `https:`. Reject `file:`, `ftp:`, `data:`, `gopher:`.
2. **DNS & IP Blacklisting**: Resolve the target hostname before making requests; block `127.0.0.0/8`, `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`, `169.254.0.0/16`, and `::1`.
3. **Resource Caps**: Enforce a 3-second network timeout, follow a maximum of 2 redirects (re-validating target IP at each step), and cap response body downloads at 512 KiB.
4. **Preview Independence**: Link preview generation is asynchronous and optional; preview failures never delay or prevent message delivery.

### Rationale
Protects backend infrastructure from internal network scanning while delivering rich visual link cards for legitimate public links.
