# Implementation Tasks: Zawolf Chat Upgrade (Rich Chat V1)

**Governing Documents**: `specs/conversations/spec.md`, `specs/conversations/plan.md`, `specs/conversations/research.md`  
**Status**: Generated Tasks (Awaiting Owner Review Before Execution)

---

## Phase 1: Setup, Characterization & Contract Definition

**Purpose**: Establish documentation, characterization tests for legacy failures, and server contract envelopes without changing live behavior.

- [x] T001 Persist approved specification (`spec.md`), technical plan (`plan.md`), architectural research (`research.md`), data model (`data-model.md`), and validation guide (`quickstart.md`) under `specs/conversations/`.
- [x] T002 [P] Characterize legacy attachment send failure, lost response handling, and duplicate retries in `scripts/test/conversations.test.js`.
- [x] T003 [P] Characterize empty-caption attachment handling and suppression of synthetic `مرفق` text in `test/features/conversations/message_delivery_test.dart`.
- [x] T004 Define `/conversations/v2` REST contract handlers, routing, and CORS in `scripts/conversations/router.js` and `scripts/http-cors.js`.
- [x] T005 [P] Implement server capability check (`/conversations/v2/capabilities`) and rollout flag `conversations_rich_chat_v1` in `scripts/conversations/router.js` and `scripts/feature-flags.js`.
- [x] T006 Add contract tests for `/conversations/v2` capabilities, channels, and error envelopes in `scripts/test/rich-conversations.test.js`.

---

## Phase 2: Local Drift Relational Storage & Outbox Sending

**Purpose**: Implement durable offline storage, WebAssembly worker assets, and optimistic outbox sending.

- [x] T007 Define pure domain entities (`RichChannel`, `RichMessage`, `RichAttachment`, `ChatDraftFile`, `ReaderPosition`, `ChannelRequest`) in `lib/features/conversations/domain/entities/rich_chat.dart`.
- [x] T008 Define `RichChatRepository` and `ChatMediaGateway` abstract domain interfaces in `lib/features/conversations/domain/repositories/`.
- [x] T009 Implement feature-owned Drift database schema (`LocalMessages`, `LocalDrafts`, `LocalDraftFiles`, `LocalPendingOperations`, `LocalReadPositions`, `LocalChannels`) in `lib/features/conversations/data/local/chat_database.dart`.
- [x] T010 Configure WebAssembly worker scripts (`web/drift_worker.js`, `web/sqlite3.wasm`) and quota failure reporting in `lib/features/conversations/data/local/chat_database.dart`.
- [x] T011 Implement `ChatStore` persistence adapter for drafts, outbox operations, and user partitioning in `lib/features/conversations/data/local/chat_store.dart`.
- [x] T012 Implement `MessageDeliveryCoordinator` outbox use case with pre-send persistence and restart recovery in `lib/features/conversations/domain/usecases/message_delivery.dart`.
- [x] T013 Implement HTTP transport client with bearer token injection and idempotent operation headers in `lib/features/conversations/data/chat_transport.dart`.
- [x] T014 Unit test Drift local store transactions, outbox queueing, and offline draft recovery in `test/features/conversations/rich_chat_repository_test.dart`.

---

## Phase 3: Resumable Media Transfers, Recording & Previews

**Purpose**: Deliver 1 MiB chunked Drive transfers, 16 kHz mono WAV voice notes, video player, and uncropped preview viewers.

- [x] T015 Implement server-side resumable upload session management and Drive file ID allocation in `scripts/conversations/uploads.js` and `scripts/conversations/drive-media-provider.js`.
- [x] T016 Implement sequential 1 MiB chunk transfer endpoint (`PUT /uploads/{resourceId}`) with offset validation and retry recovery in `scripts/conversations/uploads.js`.
- [x] T017 Implement protected attachment download endpoint with authorization checks and UTF-8 RFC 5987 content disposition in `scripts/conversations/uploads.js`.
- [x] T018 Implement client-side `ChatMediaGatewayImpl` supporting file picking (25 MiB cap, 10 file cap), saving, and native clipboard copying in `lib/features/conversations/data/media/chat_media_gateway_impl.dart`.
- [x] T019 Implement `ChatRecorderImpl` with 16 kHz mono WAV recording, 300s hardware cutoff, and microphone permission request in `lib/features/conversations/data/media/chat_recorder_impl.dart`.
- [x] T020 Build uncropped inline image viewer and fullscreen interactive zoom/pan modal with copy/save/share controls in `lib/features/conversations/presentation/widgets/chat_media_viewer.dart`.
- [x] T021 Build on-demand video player widget with first-frame preview, play/pause, and scrubber in `lib/features/conversations/presentation/widgets/chat_local_player.dart`.
- [x] T022 Build voice note recording button with live elapsed timer, cancel, preview, and send in `lib/features/conversations/presentation/widgets/voice_note_button.dart`.

---

## Phase 4: Collaboration, Receipts, Revisions & Lifecycle Sync

**Purpose**: Implement thread replies, single-reaction toggling, forwarding, 15-minute sender revisions, receipts, and bounded sync.

- [x] T023 Implement message action endpoints (`edit`, `delete`, `react`, `forward`) with 15-minute window validation and HR audit logging in `scripts/conversations/messages.js`.
- [x] T024 Implement read position updates and group reader lists in `scripts/conversations/messages.js`.
- [x] T025 Implement monotonic incremental change queries (`/channels/{id}/changes`) and 50-message history pagination in `scripts/conversations/queries.js`.
- [x] T026 Implement SSRF-safe public link preview generator in `scripts/conversations/previews.js`.
- [x] T027 Implement `ChatTimelineCubit`, `ChatComposerCubit`, and `ChatActionCubit` (each \(\le 300\) lines) in `lib/features/conversations/presentation/cubit/`.
- [x] T028 Build message bubble with thread reply preview, reaction badge, delivery state icons (pending/sent/seen), and action sheet in `lib/features/conversations/presentation/widgets/chat_message_bubble.dart`.
- [x] T029 Build group reader breakdown sheet and HR audit revision history dialog in `lib/features/conversations/presentation/widgets/chat_message_actions.dart`.
- [x] T030 Implement lifecycle-owned synchronizer with 3s active polling, 15s inbox polling, background pause, and error backoff in `lib/features/conversations/data/rich_chat_repository_impl.dart`.

---

## Phase 5: Custom Channel Requests & HR Review Queue

**Purpose**: Implement employee channel proposals, active directory picker, HR review queue, atomic approvals, and notifications.

- [x] T031 Implement active user directory lookup (`/conversations/v2/users`) in `scripts/conversations/queries.js`.
- [x] T032 Implement channel request submission, queue listing, and atomic HR review (approve/reject) in `scripts/conversations/requests.js`.
- [x] T033 Integrate deterministic notification dispatching for channel requests, approval decisions, and new messages in `scripts/conversations/requests.js`.
- [x] T034 Implement `ChatRequestsCubit` and `ChatUserPickerCubit` in `lib/features/conversations/presentation/cubit/`.
- [x] T035 Build employee channel request form page with member picker (2–100 members) in `lib/features/conversations/presentation/pages/chat_request_form_page.dart`.
- [x] T036 Build HR channel request review queue page with member adjustment and reject reason modal in `lib/features/conversations/presentation/pages/chat_requests_page.dart`.
- [x] T037 Build rich chat inbox page displaying department, manager, and custom channels with unread badges in `lib/features/conversations/presentation/pages/rich_chat_inbox_page.dart`.

---

## Phase 6: Integration, Quality Verification & Rollout

**Purpose**: Connect router entry points, resolve compilation and analysis issues, execute full verification suites, and document release readiness.

- [x] T038 Connect GoRouter routes through `RichConversationEntry` with dynamic capability fallback to legacy `ConversationEntry` in `lib/navigation/rich_conversation_entry.dart`.
- [x] T039 Resolve static analysis and syntax errors in `lib/features/conversations/` and test mocks.
- [x] T040 Run static analysis gate: `flutter analyze` (must exit 0 with 0 issues).
- [x] T041 Run architecture and Firestore query guard tests: `flutter test test/architecture_guard_test.dart test/firestore_query_guard_test.dart`.
- [x] T042 Run conversations unit and widget tests: `flutter test test/features/conversations/`.
- [x] T043 Run full client test suite: `flutter test`.
- [x] T044 Run full Hostinger Node test suite: `(cd scripts && npm test)`.
