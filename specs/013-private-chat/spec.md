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
