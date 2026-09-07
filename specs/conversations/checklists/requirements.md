# Requirements Checklist: Zawolf Chat Upgrade (Rich Chat V1)

**Feature**: Zawolf Chat Upgrade  
**Location**: `specs/conversations/checklists/requirements.md`  
**Status**: Specification Phase (Pre-Implementation Review)

---

## 1. Architecture and Compatibility
- [x] Implemented within `lib/features/conversations/` beside legacy screens.
- [x] Focused Cubits for channels, timeline, composer, media, and HR requests (all \(\le 300\) lines).
- [x] Feature-owned Drift database for local messages, drafts, attachments, read positions, and outbox.
- [x] Explicit durable web storage assets (`web/drift_worker.js`, `web/sqlite3.wasm`) with quota failure surfacing.
- [x] Authoritative Firestore and protected Google Drive storage via Hostinger proxy (`scripts/conversations/`).
- [x] Legacy endpoints, routes, and attachment IDs preserved.
- [x] Separate `conversations_rich_chat_v1` rollout flag gating rich UI entry points.

## 2. Reliable Messages and Attachments
- [x] Outbox pattern: stable `operationId` per message and attachment.
- [x] Drafts and pending operations committed before clearing composer UI.
- [x] Sequential upload queue pausing message sends until all attachments complete.
- [x] Server-side idempotent message commit matching on `operationId`.
- [x] Restart and network recovery: outbox resumes in-flight transfers and send attempts.
- [x] Empty caption permitted when attachments exist.
- [x] Elimination of synthetic `مرفق` message text for new sends.
- [x] Suppression of legacy `مرفق` text when attachments accompany historical messages.
- [x] 25 MiB file size limit enforced on client and server.
- [x] 10 attachments per message limit enforced.
- [x] 4,000 text character limit enforced.
- [x] Resumable 1 MiB chunked transfers with pre-generated Drive file ID for crash recovery.
- [x] Attachment descriptors with filename, MIME type, size, kind, dimensions, and duration.
- [x] Uncropped inline image viewing and fullscreen interactive viewer.
- [x] Fullscreen controls: save (`file_picker`), clipboard copy (`super_clipboard`), and share (`share_plus`).
- [x] Native voice notes: 16 kHz mono WAV, 300s cutoff, live timer, preview, cancel, and playback.
- [x] Video playback: on-demand controller, first-frame preview, scrub bar, fullscreen.
- [x] Structured preview cards for unsupported/corrupt files with guaranteed download access.

## 3. Messaging Features and Synchronization
- [x] Thread replies with parent message reference (`replyToMessageId`) and quoted preview.
- [x] Single toggleable emoji reaction per user per message.
- [x] Forwarding with source and destination channel posting permission verification.
- [x] Attachment reference re-scoping upon forwarding without leaking source tokens.
- [x] Sender-only edit and deletion within 15 minutes of server `sentAt`.
- [x] Expected revision concurrency conflict detection on edits.
- [x] Visible tombstone (`تم حذف هذه الرسالة`) for deleted messages.
- [x] Immutable HR audit log for message revisions and deleted content.
- [x] Message delivery states: pending (optimistic), sent (server accepted), seen (read).
- [x] Foreground-only read position dispatching (only for visible rendered messages).
- [x] Detailed group reader list modal.
- [x] Unread badge counts derived from server read positions.
- [x] Nonmember HR inspection read-only mode (never marks messages read).
- [x] Bounded history pagination (50 messages per page).
- [x] Monotonic incremental change polling (100 events per poll; 3s active channel interval).
- [x] Inbox polling at 15s interval.
- [x] Polling pauses on app backgrounding; exponential backoff on network errors.
- [x] Typing indicators with 10s expiration and 5s client throttle.
- [x] Bounded channel history search (max 200 messages per request) with Arabic normalization.
- [x] Offline search transparently scoped to local Drift cache with user notice.
- [x] SSRF-safe public link previews (blocking private/loopback/metadata IPs; 512 KiB cap; 3s timeout).

## 4. Channel Requests and HR Review Queue
- [x] Employee custom channel proposal form.
- [x] Active user directory picker (`/conversations/v2/users`).
- [x] Enforces 2 to 100 members total (including requester).
- [x] Pending request queue for HR administrators.
- [x] HR capability to adjust channel name and member list before approval.
- [x] Atomic single-channel creation on approval.
- [x] Concurrency and idempotency protection against duplicate HR approvals.
- [x] Mandatory Arabic rejection reason on rejection.
- [x] Nonmember HR inspection access disclosed in UI ("عرض إداري — HR (قراءة فقط)").
- [x] Dynamic access revocation and local cache invalidation upon member removal.
- [x] Deterministic notification delivery for requests, decisions, and new messages.

## 5. Delivery and Quality Verification
- [x] Phased delivery increments defined (Increment 1: Core Reliability, Increment 2: Collaboration, Increment 3: HR Requests & Rollout).
- [x] Complete acceptance testing matrix defined in `quickstart.md`.
- [x] Parity and immediate fail-closed rollback procedures documented.
- [x] Command verification gates established (`flutter analyze`, architecture guard, query guard, test suites).
