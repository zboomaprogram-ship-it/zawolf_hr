# Implementation Plan: Governed Private Chat

**Branch**: `013-private-chat` | **Date**: 2026-09-09 | **Spec**: [spec.md](spec.md)

## Summary

Extend the existing rich-chat vertical slice with direct conversations that are server-authorized from the current organization relationship. Add a department-first eligible-contact picker, separate private/group inboxes, deterministic direct-conversation creation, and activity-based ordering. Keep the existing group implementation and its permissions intact behind the current rich-chat rollout capability.

## Technical Context

**Language/Version**: Dart/Flutter client; Node.js Hostinger rich-chat runtime  
**Primary Dependencies**: Existing Flutter BLoC/Cubit, Drift local chat store, Firebase-authenticated HTTP transport, Firestore Admin SDK rich-chat server modules  
**Storage**: Existing Firestore conversation/message state and feature-owned Drift cache  
**Testing**: Flutter unit/widget/source regression tests; Node `node:test` rich-conversation tests  
**Target Platform**: Android, iOS, desktop web, Hostinger Node runtime  
**Project Type**: Mobile/web application with authenticated server integration  
**Performance Goals**: First inbox page and eligible contacts available in under two seconds for the specified scale  
**Constraints**: Bounded pages; no client-only authorization; no unbounded organization scan; no Firestore-rule change or destructive migration; Cubits stay below 300 lines; Arabic RTL and offline states supported  
**Scale/Scope**: 50 inbox entries/page, 100 eligible users/page maximum, exactly two members per direct chat

## Constitution Check

- **Strangler Fig**: Pass. Direct chat is added as `kind: direct` beside group channels; groups and legacy routes remain available.
- **Layer boundaries**: Pass. New presentation state uses domain contracts; HTTP/Firestore stay in data/server modules.
- **Focused Cubits**: Pass. Add focused picker/section state only if existing inbox Cubit cannot remain below 300 lines.
- **Critical business behavior**: Pass. No payroll or attendance behavior is changed.
- **Spec-driven workflow**: This plan and tasks require owner review before implementation.
- **Production rules/migrations**: No rule change or migration is planned. Additive server documents use deterministic IDs and retain rollback through the rich-chat rollout flag.

## Delivery increments

1. **Authorization and direct creation**: Contact-policy module, eligible contacts, deterministic direct conversation creation, and server tests.
2. **Private inbox and picker**: Separate inbox sections, department-first picker, local cache mapping, activity ordering, Flutter tests.
3. **Synchronization and rollout**: Latest activity updates, pagination/live merge, RTL/mobile/desktop verification, flag rollout and monitoring.

## Design

### Server authorization

Create a pure `scripts/conversations/direct-policy.js` module that receives actor and target user records and returns an eligibility reason or denial. It normalizes roles and departments using existing canonical authorization utilities and treats manager chains as `managerId`, `managerIds`, and team leader.

The policy allows:

| Actor | Permitted direct contacts |
|---|---|
| Ordinary employee | Ordinary employees; direct manager chain; managers in same department; HR; super admins; IT |
| Manager | Every active user |
| Super administrator | Every active user |
| Any active user | Any active IT user |

The contact endpoints query narrowly, then apply policy before returning results. Direct creation reads the target by ID and repeats the policy inside the deterministic creation transaction. Channel access for `kind: direct` requires the actor to be one of the two participant IDs; message and media operations use the same `common.access` path.

### Conversation identity and activity

Add `kind: direct`, `participantUserIds`, `pairKey`, `latestActivityAt`, and `latestActivityId` as additive fields. The canonical pair key is derived from sorted user IDs. A transaction creates/returns a single `direct:<pair-key>` conversation and writes an idempotent operation receipt. Existing send/edit/delete/reaction flows update latest activity atomically with their existing change sequence.

### Inbox and cache

Extend `RichChannel` DTOs with activity fields and direct participant display data. Add `section=direct|group` to the new channels contract while preserving the existing unqualified route during rollout. Update the repository, codec, and local store so private and group pages are cached separately. The inbox presentation shows two visible RTL tabs/segmented sections, each with its own cursor and newest-first merge. A direct conversation name is the other participant’s name.

### Picker

Add a department-selection page/state before the existing user list. After choosing a department, fetch only authorized contacts for it. Display separate controlled shortcut sections for manager, HR, admin, and IT. Starting a contact invokes `POST /direct`, then opens the returned channel.

### Synchronization and error behavior

Inbox refresh is lifecycle-owned as today. A new message moves its direct/group channel to the top of the matching inbox after the next bounded change/inbox update. Cached data remains marked offline. `access_denied`, inactive targets, and stale picker selections display safe Arabic feedback without target metadata.

## Project Structure

```text
specs/013-private-chat/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── contracts/private-chat.md
├── quickstart.md
└── tasks.md

scripts/conversations/
├── direct-policy.js
├── direct.js
├── common.js
├── queries.js
├── router.js
└── test/rich-conversations.test.js

lib/features/conversations/
├── data/chat_codec.dart
├── data/rich_chat_repository_impl.dart
├── data/local/chat_database.dart
├── domain/entities/rich_chat.dart
├── domain/repositories/rich_chat_repository.dart
└── presentation/
    ├── cubit/chat_inbox_cubit.dart
    ├── cubit/chat_direct_picker_cubit.dart
    └── pages/{rich_chat_inbox_page,direct_chat_picker_page}.dart
```

**Structure Decision**: Extend the existing conversations vertical slice. The new direct-policy/server modules are the authorization boundary; presentation remains independent of concrete storage and HTTP implementations.

## Rollout and rollback

Deploy the additive Hostinger server modules before client use. Keep direct chat behind `conversations_rich_chat_v1`. Monitor denied creation attempts, duplicate direct-pair attempts, inbox latency, and failures without storing message content. Disable the feature flag to roll back the client route; direct conversation and message records remain intact for later re-enable.
