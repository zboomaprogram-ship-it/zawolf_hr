# Research: Governed Private Chat

## Decision: Use the existing rich-chat conversation resource with a `direct` kind

**Rationale**: Rich chat already provides durable messages, attachments, read positions, typing, change synchronization, local storage, and endpoint routing. A direct conversation needs the same behavior with a stricter two-participant authorization rule.

**Alternatives considered**:
- A separate private-message collection: rejected because it would duplicate delivery, attachment, audit, and synchronization behavior.
- Client-only contact filtering: rejected because a forged or cached client request could bypass it.

## Decision: Evaluate contact eligibility from current authoritative user records on every server operation

**Rationale**: Department, role, manager chain, active state, and IT assignment can change. Server evaluation prevents stale local data and guessed conversation IDs from granting access.

**Alternatives considered**:
- Save permanent contact grants: rejected because they become stale after organizational changes.
- Depend only on Firestore rules: rejected because the rich-chat server is the mutation and protected-media authority.

## Decision: Use a deterministic pair key and transaction for direct conversation creation

**Rationale**: Sorting the two participant IDs and deriving one canonical pair key makes repeated taps, network retries, and concurrent starts converge on one conversation.

**Alternatives considered**:
- Generate a random channel ID per start: rejected because it creates duplicate direct chats.

## Decision: Return separate bounded private and group inbox pages ordered by activity

**Rationale**: The user needs visual separation and WhatsApp-like recency. A server-side activity cursor avoids one large client-side merge and preserves stable pagination.

**Alternatives considered**:
- Fetch all conversations and sort locally: rejected because it grows unbounded and delays inbox loading.

## Decision: Department-first picker with permitted shortcut sections

**Rationale**: The requested flow is department then person. The actor's direct managers, HR, super administrators, and IT are cross-department exceptions, so they remain reachable through explicit sections without making the department list misleading.

**Alternatives considered**:
- A flat organization-wide search: rejected because it violates the requested selection flow and invites accidental contact attempts.
