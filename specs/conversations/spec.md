# Feature Specification: Zawolf Chat Upgrade (Rich Chat V1)

**Feature Boundary**: `lib/features/conversations/`, `scripts/conversations/`, `specs/conversations/`  
**Created**: 2026-09-06  
**Status**: Approved Specification  
**Rollout Flag**: `conversations_rich_chat_v1`

---

## 1. Executive Summary & Problem Statement

Zawolf HR employees, managers, and HR personnel rely on internal conversations for daily operational communication, attendance clarification, and document exchange. The legacy chat interface suffers from several critical operational limitations:
1. **Send fragility & lost attachments**: Attachment uploads and message creation can race, fail silently on transient network blips, or leave messages in limbo without durable draft recovery or deduplication on retry.
2. **Media constraints & synthetic captions**: Messages with attachments forcibly inject placeholder text (`مرفق`), crop images awkwardly, lack zoom/copy/save capabilities, and lack support for native voice notes and video playback.
3. **Absence of modern collaboration tools**: No message replies, emoji reactions, message forwarding, sender editing/deletion, delivery/read receipts, or typing indicators.
4. **Channel sprawl & ungoverned creation**: All channels are strictly department or manager channels without a mechanism for project-specific or cross-departmental working groups.
5. **High Firestore read costs**: Full-history repeated polling creates unnecessary read volume, battery drain, and rate-limiting risks on mobile and web clients.

The **Zawolf Chat Upgrade** resolves these issues through a feature-owned, Strangler Fig vertical slice beside legacy chat. It introduces durable offline drafts, chunked resumable 25 MiB Drive transfers, rich multimedia handling, sender-only versioned edit/delete with tombstones and HR audit history, an atomic employee custom channel request workflow, and bounded incremental synchronization.

---

## 2. User Scenarios & Testing (Mandatory)

### User Story 1 — Reliable Sending and Durable Offline Drafts (Priority: P1)

An employee composes a message with text, attachments, or both. If the network drops, the application closes, or the device restarts before upload completion, the draft and pending operations remain fully preserved in local storage. Retries execute idempotently without creating duplicate messages or orphaned files.

**Why this priority**: Message delivery and draft preservation are foundational; losing employee messages or file attachments damages business communication trust.

**Independent Test**: Simulate upload failures, forced app termination mid-upload, network disconnects during send, and rapid retry button presses. Verify zero duplicate messages on the server, draft retention across restarts, and accurate optimistic UI states.

**Acceptance Scenarios**:
1. **Given** an employee composes a message with attachments, **When** they press send, **Then** pending operations and drafts are committed to the local Drift database before the composer is cleared from active view.
2. **Given** an attachment upload is in progress, **When** the network disconnects or times out, **Then** the message transitions to a clear `failed` state with retry and cancel controls; partial chunks already uploaded are preserved.
3. **Given** a send operation failed or the app was closed during flight, **When** the app restarts, **Then** the pending operation and draft files are restored from local persistence with their original content intact.
4. **Given** an attachment is sent without text, **When** the message is created, **Then** no synthetic `مرفق` text is added, and the caption remains empty.
5. **Given** historical messages with attachments contain legacy `مرفق` text, **When** rendered in the timeline, **Then** the synthetic `مرفق` text is suppressed only when actual attachments accompany the message.
6. **Given** an identical message send operation is re-transmitted due to network uncertainty, **When** the server processes the request with the same `operationId`, **Then** the operation succeeds idempotently, returning the existing message record without creating a duplicate.

---

### User Story 2 — Resumable Media Transfers, Inline Previews, and Native Fallbacks (Priority: P1)

An employee shares images, voice notes, videos, PDFs, or office documents up to 25 MiB. Images display inline at full aspect ratio without cropping, support fullscreen zoom with save/copy/share, audio/video play directly within the timeline, and documents render with descriptive preview cards.

**Why this priority**: Teams exchange critical operational evidence (leave medical notes, attendance sheets, sales reports, and receipts); previews must be seamless and never block file access.

**Independent Test**: Upload 24.9 MiB files, corrupt media streams, portrait/tall images, Arabic-named documents, and multi-file batches (up to 10 files). Test clipboard copy on desktop web, microphone permission denial, and 300-second voice recording cutoffs.

**Acceptance Scenarios**:
1. **Given** a file up to 25 MiB, **When** selected for upload, **Then** the client transfers the file in sequential 1 MiB binary chunks with `X-Upload-Offset` and `X-Operation-Id` headers to `/conversations/v2/channels/{id}/uploads/{resourceId}`.
2. **Given** a selected file exceeds 25 MiB or the message exceeds 10 attachments, **When** the user attempts to attach them, **Then** the action is rejected immediately with an Arabic explanatory dialog and no network transfer starts.
3. **Given** an image is rendered in the timeline, **When** viewed, **Then** it renders uncropped; tapping the image opens a fullscreen interactive viewer with zoom, pan, save to device, copy to clipboard (`super_clipboard`), and system share (`share_plus`).
4. **Given** an employee initiates a voice note, **When** recording starts, **Then** microphone permissions are requested; recording captures 16 kHz mono WAV audio with a live elapsed timer, pause, cancel, preview, and send controls, cutting off automatically at 300 seconds.
5. **Given** a video file is attached, **When** viewed in the timeline, **Then** a first-frame preview is shown with on-demand video player loading, play/pause, seek bar, and fullscreen playback controls.
6. **Given** a document or media file with an unsupported or corrupt preview format, **When** displayed, **Then** a structured file card shows filename, MIME type, and size with download and share actions, never crashing the timeline or blocking file retrieval.
7. **Given** authorized media is downloaded, **When** retrieved from `/attachments/{resourceId}/download`, **Then** authenticated binary bytes are cached in private local files (or browser Blob URLs) and released when appropriate.

---

### User Story 3 — Thread Replies, Single-Reaction Toggling, Forwarding, and Revisions (Priority: P1)

Users reply directly to existing messages, toggle one emoji reaction per message, and forward messages to other channels where they have post permissions. Senders can edit or delete their messages within a strict 15-minute window from server acceptance, leaving visible indicators and an immutable HR audit trail.

**Why this priority**: Clarifications require threaded context; accidental typos or incorrect attachments require timely correction without compromising organizational accountability.

**Independent Test**: Reply to deeply nested threads, toggle emoji reactions multiple times, forward to unauthorized channels (verify denial), attempt editing at 14m59s (allowed) vs 15m01s (rejected), and verify HR revision history audit view.

**Acceptance Scenarios**:
1. **Given** an existing message, **When** a user swipes or chooses reply, **Then** the composer quotes the target message with sender name and preview; the resulting message references `replyToMessageId`.
2. **Given** an existing message, **When** a user adds an emoji reaction, **Then** selecting the same emoji removes it, while selecting a different emoji replaces it (exactly one reaction per user per message).
3. **Given** a message with or without attachments, **When** a user forwards it to another channel, **Then** the server verifies the user's post permission in the target channel and creates new destination-scoped attachment references without leaking source channel authorization tokens.
4. **Given** a sender posted a message less than 15 minutes ago, **When** they edit the text, **Then** the server updates the text, increments `revision`, sets `editedAt`, and preserves earlier revisions in the HR audit log.
5. **Given** a sender posted a message less than 15 minutes ago, **When** they delete the message, **Then** the server marks it deleted (`deletedAt`), clears the body, leaves a visible tombstone (`تم حذف هذه الرسالة`), and retains the original content exclusively for HR audit review.
6. **Given** a message was sent more than 15 minutes ago or the editor is not the original sender, **When** an edit or delete action is attempted, **Then** the server rejects the request with an HTTP 403 / `edit_window_expired` error code.
7. **Given** concurrent edits to the same message, **When** submitted with an outdated `expectedRevision`, **Then** the server returns an HTTP 409 conflict and the client displays the conflict state with resolution options.

---

### User Story 4 — Read Receipts, Unread Badges, and Bounded Incremental Synchronization (Priority: P1)

The client reflects message states: pending, sent (server acknowledged), and seen (read by recipients). Group conversations expose detailed reader breakdowns. Background synchronization runs efficiently without battery drain or excessive Firestore read costs.

**Why this priority**: Operational coordination depends on knowing whether instructions have been seen, while bounding cloud database read budgets.

**Independent Test**: Measure Firestore query counts during active chatting, verify background polling pauses when the app is minimized, verify read positions are only dispatched for messages rendered in an active foreground route, and inspect group reader sheets.

**Acceptance Scenarios**:
1. **Given** an active foreground channel, **When** messages are rendered on screen, **Then** the client records the highest seen message ID and dispatches a debounced read position update to `/channels/{id}/read`.
2. **Given** the app is running in the background, minimized, or the channel route is not the active foreground route, **When** new messages arrive, **Then** no read position updates are dispatched, and polling frequency drops from 3s to 15s or pauses completely.
3. **Given** a channel message, **When** a user taps message details, **Then** a reader list displays each participant who read the message along with their read timestamp.
4. **Given** an HR administrator inspects a custom channel as a nonmember, **When** they read messages, **Then** their view is strictly read-only and does not advance reader positions or mark messages as read for members.
5. **Given** an active channel timeline, **When** synchronizing changes, **Then** the client queries `/channels/{id}/changes?after={changeCursor}&limit=100`, receiving only new messages, edits, deletions, reactions, and read position changes.
6. **Given** historical timeline navigation, **When** the user scrolls up, **Then** older messages are loaded in pages of 50 using `before={messageId}` cursors without re-fetching existing cached history.

---

### User Story 5 — Governed Custom Channel Requests and HR Review Queue (Priority: P1)

Employees can propose custom group channels for cross-functional initiatives by selecting active colleagues, specifying a channel name, and providing a business justification. HR administrators review proposals in a dedicated queue, adjust names or membership if needed, and atomically approve (instantiating the channel) or reject with an explanation.

**Why this priority**: Prevents uncontrolled group channel proliferation while empowering cross-departmental collaboration under HR oversight.

**Independent Test**: Create a request with 1 colleague (fails: minimum 2 members including requester), create a request with 3 colleagues (succeeds: pending state), simulate duplicate approval by two HR admins simultaneously (atomic single channel creation), verify membership adjustment, and verify nonmember HR audit access disclosure.

**Acceptance Scenarios**:
1. **Given** an employee opens "Request Channel", **When** selecting members, **Then** only active employees from `/conversations/v2/users` are selectable, and the total member count (including requester) must be between 2 and 100.
2. **Given** a submitted channel request, **When** stored, **Then** its initial status is `pending`; employees see it in "My Requests" and HR admins see it in the "HR Review Queue".
3. **Given** an HR administrator reviews a pending request, **When** evaluating the request, **Then** HR can edit the channel name, add or remove members, and either approve or reject with a mandatory Arabic reason.
4. **Given** an HR approval action is executed, **When** committed on the server, **Then** one custom channel is created atomically, linked to `request.conversationId`, and notifications are dispatched to all initial members.
5. **Given** two HR administrators attempt to approve the same pending request concurrently, **When** the second approval arrives with a stale `expectedRevision`, **Then** the server returns the already-created channel or an explicit conflict error without creating duplicate channels.
6. **Given** an approved custom channel, **When** an HR administrator views it without being a listed member, **Then** the interface clearly discloses: "عرض إداري — HR (قراءة فقط)" and disables message composition.
7. **Given** a member is removed from a custom channel, **When** their next synchronization request runs, **Then** server access is revoked, and the local cached channel is invalidated.

---

### User Story 6 — Channel History Search and Public Link Previews (Priority: P2)

Users search within authorized channels across cached and server history using normalized Arabic and English matching. Public links typed into messages generate rich metadata previews without exposing the server to Server-Side Request Forgery (SSRF).

**Why this priority**: Search enables finding operational records quickly; link previews enrich external references safely.

**Independent Test**: Search with Arabic diacritics, prefixes, and varying alef forms (`أ`, `إ`, `آ`, `ا`); test link previews with private IP addresses (`10.0.0.1`, `127.0.0.1`, `169.254.169.254` - verify blocked); verify offline search indicates cached-only scope.

**Acceptance Scenarios**:
1. **Given** a search query in an authorized channel, **When** executed, **Then** the server scans messages in bounded batches of 200 rows with an explicit continuation cursor, normalizing Arabic alefs, tah marbuta, and case.
2. **Given** the device is offline, **When** the user searches, **Then** the search runs against the local Drift database and prominently displays an indicator: "نتائج البحث من السجل المحفوظ محلياً فقط".
3. **Given** a message contains a URL, **When** composer or timeline requests a preview via `/channels/{id}/preview`, **Then** the server validates the URL: allowing only public HTTP/HTTPS schemes, strictly blocking private/loopback/cloud-metadata IPs, capping response size to 512 KiB, and timing out after 3 seconds.
4. **Given** link preview generation fails or is rejected, **When** rendered, **Then** the URL remains clickable and message sending is never blocked.

---

## 3. Business Rules, Constraints & Architectural Guardrails

### 3.1 Hard Limits
| Parameter | Rule / Limit | Failure Mode |
|---|---|---|
| Max Attachment Size | 25 MiB (26,214,400 bytes) per file | Rejected on client before upload; validated on server |
| Max Attachments Per Message | 10 files | Rejected on selection; validated on server |
| Max Message Body Length | 4,000 UTF-8 characters | Client character counter; rejected on server |
| Max Voice Note Duration | 300 seconds (5 minutes) | Recorder automatically stops at 300s |
| Resumable Chunk Size | 1 MiB (1,048,576 bytes) sequential | Last chunk may be \(\le 1\text{ MiB}\) |
| Edit / Deletion Window | 15 minutes (900 seconds) from server `sentAt` | Server rejects with `edit_window_expired` |
| Custom Channel Member Limits | 2 minimum, 100 maximum (including requester) | Form validation; rejected on server |
| Typing Indicator Timeout | 10 seconds expiration; 5 seconds throttle | Client suppresses redundant pings |
| History Pagination Limit | 50 messages per page | Enforced by cursor query |
| Incremental Change Limit | 100 events per poll | Enforced by monotonic change cursor |
| Search Scan Limit | 200 messages per request | Returns `hasMore` and `nextCursor` |

### 3.2 Arabic Localization & RTL Rules
1. **Directionality**: All conversation screens, drawers, dialogs, and cards must reside within an explicit `Directionality(textDirection: TextDirection.rtl)`.
2. **Icon Mirroring**: Back arrows, forward arrows, chevrons, and timeline layout must respect RTL conventions.
3. **Caption Cleansing**: The legacy automatic placeholder `مرفق` is discontinued. Senders may submit empty text when attachments exist.
4. **Historical Suppression**: When rendering legacy messages that contain the exact text `مرفق` and have attachments, the UI suppresses the text and renders only the attachments.
5. **Arabic Status Strings**: All UI feedback, connection states, and error alerts must use clean, professional Arabic terminology.

### 3.3 Architecture & Layer Integrity
1. **Domain Purity**: `lib/features/conversations/domain/` has zero dependencies on Flutter, Firebase, Firestore, Dio, Drift, or HTTP.
2. **Presentation Decoupling**: `lib/features/conversations/presentation/` interacts solely with Domain contracts and Cubits. No direct imports of Firestore, Drive, or HTTP transport.
3. **Cubit Line Limit**: Every Cubit in `presentation/cubit/` must strictly remain under 300 lines of code. Repositories and adapters own complex logic.
4. **Feature Flag Isolation**: `conversations_rich_chat_v1` is checked at composition root ([`RichConversationEntry`](file:///Users/seg/Shemais/Shemais/zawolf_hr/lib/navigation/rich_conversation_entry.dart)). If disabled, users seamlessly see the legacy [`ConversationEntry`](file:///Users/seg/Shemais/Shemais/zawolf_hr/lib/navigation/conversation_entry.dart).

### 3.4 Target Platform Matrix
1. **Web**: Desktop Google Chrome and Brave (Chromium runtime environment, WebAssembly worker, and OPFS/IndexedDB persistence).
2. **Mobile**: Native iOS and Android applications.
3. **Desktop**: Linux and Windows applications (along with macOS), using shared Flutter engine, native SQLite, and standard desktop media integrations.

---

## 4. Acceptance Verification Commands

Before any increment is handed off, all repository guards and test suites must pass cleanly:

```bash
# 1. Static Analysis
flutter analyze

# 2. Architecture and Query Guards
flutter test test/architecture_guard_test.dart test/firestore_query_guard_test.dart

# 3. Feature Unit & Widget Tests
flutter test test/features/conversations/

# 4. Full Flutter Test Suite
flutter test

# 5. Hostinger Node Server Test Suite
(cd scripts && npm test)
```
