# Feature Specification: Governed Private Chat

**Feature Branch**: `013-private-chat`  
**Created**: 2026-09-09  
**Status**: Draft — awaiting owner review  
**Feature Boundary**: `lib/features/conversations/`, `scripts/conversations/`, `specs/013-private-chat/`

## User Scenarios & Testing

### User Story 1 — Start an authorized private chat (Priority: P1)

An employee opens the private-chat area, chooses a department, then chooses one eligible person from that department. The system opens the existing private conversation or creates exactly one new conversation. The employee sees only people they are allowed to contact.

**Why this priority**: Private operational communication must be available without exposing employees to unauthorized managers or creating duplicate conversations.

**Independent Test**: Sign in as a regular employee, select a department, and verify that permitted employees, the direct manager, HR, super administrators, and IT staff appear only when allowed; attempt every forbidden selection and verify it is absent and rejected if requested directly.

**Acceptance Scenarios**:

1. **Given** two active ordinary employees, **When** either chooses the other through the department-first picker, **Then** they can open one shared private conversation regardless of department.
2. **Given** an ordinary employee, **When** choosing their direct manager or a manager in the same department, **Then** the manager is eligible.
3. **Given** an ordinary employee, **When** choosing a manager in another department who is not in their assigned manager chain, **Then** that manager is not eligible and the conversation cannot be created.
4. **Given** an ordinary employee, **When** choosing HR, a super administrator, or any active IT employee, **Then** that person is eligible regardless of department or reporting line.
5. **Given** a manager, **When** choosing any active employee, manager, HR staff, or administrator, **Then** the person is eligible.
6. **Given** a super administrator, **When** choosing any active user, **Then** the person is eligible.
7. **Given** a deactivated, missing, or self user, **When** the picker is loaded, **Then** that user is not selectable.
8. **Given** a client submits a forged private-chat target, **When** the request reaches the service, **Then** it is rejected unless the same eligibility rule permits it.

---

### User Story 2 — Separate private chats and groups (Priority: P1)

A user sees two separate inboxes: private chats and groups. Existing department, manager, and custom group conversations remain in Groups. Private conversations never appear in Groups.

**Why this priority**: Users can find a person quickly without mixing one-to-one conversations with operational groups.

**Independent Test**: Create or open both a private chat and each group type; verify each appears in exactly its correct inbox, including after a refresh and on mobile and desktop layouts.

**Acceptance Scenarios**:

1. **Given** a user opens Chat, **When** the inbox loads, **Then** Private and Groups are visibly separate choices with Arabic RTL labels.
2. **Given** a department, manager, or approved custom conversation, **When** listed, **Then** it appears only in Groups.
3. **Given** a private conversation, **When** listed, **Then** it appears only in Private chats and identifies the other participant.
4. **Given** a user has no private chats, **When** opening Private chats, **Then** they receive an empty state with a clear action to choose a department and person.

---

### User Story 3 — Recent conversations appear first (Priority: P1)

Both private chats and groups are ordered like WhatsApp: the conversation with the newest visible activity appears first. Unread counts remain accurate and do not change the activity order.

**Why this priority**: Employees need to return to the latest discussion immediately.

**Independent Test**: Send messages in several private chats and groups at controlled times, refresh and paginate the inbox, and confirm exact newest-first ordering across devices.

**Acceptance Scenarios**:

1. **Given** two conversations with different latest-message times, **When** the inbox opens, **Then** the newer conversation appears first.
2. **Given** a newly sent or received message, **When** synchronization completes, **Then** its conversation moves to the top of its own inbox without a manual refresh.
3. **Given** equal activity timestamps, **When** ordering the inbox, **Then** a stable deterministic tie-breaker produces the same order on every client.
4. **Given** a user loads older inbox pages, **When** merging them with live updates, **Then** no conversation duplicates and newest-first ordering remains intact.

### Edge Cases

- A direct manager changes after a private chat already exists: existing history remains readable to its two participants; a new conversation request is rechecked against the current relationship.
- A participant becomes inactive: the existing chat remains visible as history but posting is disabled and the user cannot be selected for a new private chat.
- A user loses an HR, IT, manager, or super-administrator role: future access and new conversations follow the current role; no client cache grants access.
- The same two users start a conversation simultaneously: both receive the same direct conversation, with no duplicate channel.
- Departments with no eligible users show an explanatory Arabic empty state and a department change action.

## Requirements

### Functional Requirements

- **FR-001**: The system MUST authorize every private-chat read, creation, message action, attachment operation, and download on the server using current user records.
- **FR-002**: An ordinary employee MUST be able to privately contact active ordinary employees, their direct manager chain, managers in their own department, active HR staff, active super administrators, and active IT employees.
- **FR-003**: An ordinary employee MUST NOT be able to start a private chat with a manager in another department unless that manager is in the employee's direct manager chain.
- **FR-004**: A manager MUST be able to privately contact every active user.
- **FR-005**: A super administrator MUST be able to privately contact every active user.
- **FR-006**: Every active employee MUST be able to privately contact every active IT employee.
- **FR-007**: The contact picker MUST require department selection before displaying eligible people, except for explicit shortcut sections for the employee's manager, HR, super administrators, and IT.
- **FR-008**: The picker MUST not return users whom the current employee cannot contact, and its server response MUST be bounded and paginated.
- **FR-009**: A direct conversation MUST contain exactly two immutable participant identifiers and use a deterministic pair identity so concurrent or repeated starts return the same conversation.
- **FR-010**: Group conversations (department, manager, and custom) and direct conversations MUST be returned and rendered as separate inbox categories.
- **FR-011**: Each inbox category MUST be ordered by most recent visible message activity descending, with a deterministic tie-breaker and stable pagination.
- **FR-012**: Sending a message, edit, deletion, reaction, or attachment change MUST update the affected conversation's latest activity without exposing inaccessible content.
- **FR-013**: Existing group permissions, HR/admin custom-group moderation, message audit history, attachments, receipts, and feature-flag behavior MUST remain unchanged.
- **FR-014**: Unauthorized direct-conversation requests, including guessed identifiers and stale cached picker results, MUST return a safe access-denied outcome without revealing target details.
- **FR-015**: Arabic RTL, mobile, desktop web, loading, empty, offline, and error states MUST be available for both inboxes and the department-first picker.

### Key Entities

- **Direct Conversation**: A two-person conversation with immutable participants, deterministic pair identity, latest activity position, and inherited rich-chat state.
- **Eligible Contact**: An active user who the current actor may contact, with the current reason for eligibility and department for picker grouping.
- **Inbox Section**: A filtered view of either private conversations or groups, with a cursor and deterministic activity order.

## Success Criteria

### Measurable Outcomes

- **SC-001**: An eligible user can select a department, choose a contact, and reach an existing or new private chat in three interactions or fewer.
- **SC-002**: 100% of attempted private-chat operations by ineligible actors are denied by the authoritative service, including requests made outside the picker.
- **SC-003**: In controlled inbox tests, 100% of conversations appear in the correct Private or Groups section and are ordered newest to oldest after refresh and live updates.
- **SC-004**: Opening either inbox returns its first visible page within two seconds on representative mobile and desktop connections when the account has up to 50 conversations in that section.
- **SC-005**: Concurrent starts between the same two users produce one conversation in 100% of tested retries.

## Assumptions

- “IT” means active users whose department or position identifies them as IT/Information Technology in the same canonical manner used elsewhere in the product.
- “Direct manager” includes the current `managerId`, ordered `managerIds`, and assigned team leader where present.
- Ordinary employees may contact ordinary employees across departments; the restriction applies to managers in other departments unless directly assigned.
- Existing private conversations retain historical visibility for their two participants even if a later reporting-line change would prevent creating a new one.
- This feature extends the existing rich-chat rollout and remains disabled for users outside `conversations_rich_chat_v1` until deliberately enabled.

---

## Extension: Rich Group Experience, Media, and Notifications

**Status**: Draft — awaiting owner review (2026-09-09)

### User Story 4 — Useful group and member information (Priority: P1)

A user can open a polished group information page with the group image/name, clear purpose and visibility, member count, searchable member list, shared media/documents, notification controls, and the participant actions that their role permits. It follows the practical information layout of WhatsApp while retaining ZaWolf branding and Arabic RTL.

**Acceptance Scenarios**:

1. Group and direct-chat headers show the correct name, avatar, participant count, and information action without unknown/fallback icons.
2. The information page displays only members the current user is authorized to see; direct chats show exactly the other participant and groups show their authorized member list.
3. HR/admin group moderation controls are visible only where the existing authorization policy permits them.
4. Group detail pages provide loading, empty, error, offline, mobile, desktop-web, and Arabic RTL states.

### User Story 5 — Expressive but governed messaging (Priority: P1)

A participant can react with an expanded approved emoji set and use locally bundled sticker packs. Stickers are message attachments with a server-approved pack/item identifier, never arbitrary remote image URLs.

**Acceptance Scenarios**:

1. The reaction picker contains a larger fixed Unicode emoji palette and preserves the existing one-reaction-per-user rule.
2. A sticker picker lists bundled approved packs, sends a stable sticker identifier, and renders it offline when the pack is installed.
3. A user cannot submit an unrecognized sticker identifier or arbitrary image as a sticker.

### User Story 6 — Reliable chat notifications and deep links (Priority: P0)

A message notification reaches authorized recipients in foreground, background, and after the app has been closed. Tapping it opens the exact authorized conversation, or a safe notification/error screen if the channel was removed or access changed.

**Acceptance Scenarios**:

1. Sending a message creates one deterministic notification event per eligible recipient and does not notify the sender.
2. Notification delivery is queued independently from the committed message and retries transient provider failures without duplicating a visible notification.
3. The app maps a chat notification route to the specified conversation ID after authentication and rechecks access before opening it.
4. Android/iOS use a short, licensed app notification sound derived from the approved alarm asset; web uses browser-supported notification behavior. A missing sound falls back to the platform default.

### User Story 7 — Company-wide general group (Priority: P1)

Every active employee can read and post in one canonical company group. Deactivated users lose future access. The group has a deterministic ID, is created idempotently by the server, and appears in Groups.

### User Story 8 — Complete, calm file handling (Priority: P1)

Messages with images, documents, spreadsheets, PDFs, audio, video, and unsupported files render without an excessively bright background. Each file has a clear type card and safe open/save/share actions; supported types provide previews and unsupported/corrupt types remain downloadable.

### Extension Requirements

- **FR-016**: Group and direct information screens MUST be feature-owned, role-aware, Arabic RTL, and must not expose unauthorized members or controls.
- **FR-017**: The app MUST use approved emoji and packaged sticker identifiers; the server validates every sticker before persisting it.
- **FR-018**: Message notification persistence, delivery retry, and notification tap routing MUST be idempotent and independent from message commit success.
- **FR-019**: A notification tap MUST authenticate and authorize the target conversation before navigation; stale/removed targets MUST show safe Arabic feedback.
- **FR-020**: The company group MUST use a stable server-owned ID and active-employee authorization on every read/post/action/download.
- **FR-021**: File presentation MUST handle image, PDF, plain text, spreadsheet, Word document, audio, video, archive, and unknown MIME types with a readable dark theme and download fallback.
- **FR-022**: The notification sound asset and native platform configuration MUST be delivered only in a store update, not a Shorebird/Dart patch, because native packaged resources are required.

### Extension Success Criteria

- Every notification-tap test opens the intended authorized conversation and no other channel.
- Every tested file type remains readable or downloadable after send, including Arabic filenames and corrupt/unsupported previews.
- The company group is created once under concurrent initialization and is accessible to every active employee.
