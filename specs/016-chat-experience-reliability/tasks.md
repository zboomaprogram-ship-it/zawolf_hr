# Tasks: Chat Experience and Reliability

**Status:** Approved — implementation in progress

- [ ] Add domain entities/contracts for per-user channel preference and active-channel alert suppression.
- [ ] Add server preference endpoint support for mute, archive, restore, and archived-list state with idempotent operation receipts.
- [ ] Filter default direct inbox results by participant archive state; provide a bounded archived inbox route.
- [ ] Suppress active-channel in-app/local notification delivery and mark the matching notification read safely.
- [ ] Suppress muted and archived chat notifications in both client alert and Hostinger dispatcher paths.
- [ ] Add invalid-OneSignal-alias subscription-repair handling and tests.
- [ ] Build authorized direct/group notification titles and sender-aware notification bodies.
- [ ] Remove redundant rich-chat bootstrap/listener work; preserve cache while network refreshes.
- [ ] Measure and correct the inbox query path so authorized channels are bounded and do not depend on scanning unrelated conversations.
- [ ] Upload independent attachments with bounded concurrency; retain per-file ordered resumable chunks and retry.
- [ ] Persist upload jobs/offsets so transfers continue during in-app navigation and resume after interruption.
- [ ] Define and implement user-scoped smart-cache TTL, size limits, LRU eviction, refresh-in-place, logout, and access-revocation cleanup.
- [ ] Render locally stored images, voice notes, videos, and documents offline, using the existing governed attachment descriptor as the re-download source when bytes are absent.
- [ ] Add a confirmed local-copy deletion action that preserves chat history and remote media, then exposes **تنزيل** to retrieve the attachment again.
- [ ] Add a chat-storage setting that shows local media use and clears cached copies without deleting message history.
- [ ] Add web clipboard-image ingestion and composer preview; document native store-build dependency.
- [ ] Plan native background-transfer and raw clipboard-image support as a separate store-build increment.
- [ ] Restyle chat bubbles, receipts, tails, composer, and inbox using logo-derived blue theme tokens.
- [ ] Rename all user-facing **شات القسم** entry labels to **المحادثات**.
- [ ] Add explicit chat-info close/back control and RTL navigation tests.
- [x] Add accessible Arabic date separators for today, yesterday, and older message groups.
- [ ] Add swipe archive, undo, restore, and archived inbox UI for direct chats.
- [ ] Run the required Flutter and Node checks and prepare Hostinger deployment artifacts.
