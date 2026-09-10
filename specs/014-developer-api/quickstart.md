# External Developer API — Integration Guide

The server publishes versioned, read-only endpoints at `https://notification.zawolf.ai/developer-api/v1/`. Clients must never use Firebase credentials, Firebase ID tokens, or a service-account file.

## Owner: create a client

An active HR/super-admin account calls the following endpoint using its Firebase **ID token**. The `secret` response is shown once. Store it in the developer's secret manager, never in source control.

```bash
curl --request POST 'https://notification.zawolf.ai/developer-api/v1/admin/clients' \
  --header "Authorization: Bearer $OWNER_FIREBASE_ID_TOKEN" \
  --header 'Content-Type: application/json' \
  --data '{
    "name": "Approved partner integration",
    "scopes": ["directory.read"],
    "expiresAt": "2026-12-31T23:59:59.000Z"
  }'
```

Only `directory.read` is available in the first release. It returns employee ID, display name, department, position, manager ID, and active state. It does not return email, salary, payroll, chat content, notification tokens, device identifiers, raw locations, biometrics, passwords, or Firebase metadata.

## Developer: read the directory

```bash
curl 'https://notification.zawolf.ai/developer-api/v1/users?limit=50' \
  --header "Authorization: Bearer $ZAWOLF_DEVELOPER_API_SECRET"
```

Use `nextCursor` only with the same credential that received it:

```bash
curl "https://notification.zawolf.ai/developer-api/v1/users?limit=50&cursor=$NEXT_CURSOR" \
  --header "Authorization: Bearer $ZAWOLF_DEVELOPER_API_SECRET"
```

The API accepts at most 100 records per page and 60 requests per minute per client/network. Retrieve the contract from `/developer-api/v1/openapi.json`.

## Owner: revoke immediately

```bash
curl --request POST "https://notification.zawolf.ai/developer-api/v1/admin/clients/$CLIENT_ID/revoke" \
  --header "Authorization: Bearer $OWNER_FIREBASE_ID_TOKEN" \
  --header 'Content-Type: application/json' \
  --data '{"reason":"Integration access ended"}'
```

Revocation takes effect on the next request. The server records credential lifecycle and request audit entries without storing the secret or authorization header.

## Deployment

Deploy the Hostinger Node runtime and the two Firestore indexes in `firestore.indexes.json` before issuing a client. Verify `/developer-api/v1/openapi.json`, then create a short-lived directory-only credential and test list, cursor, expiry, and revocation. If a problem occurs, revoke every client; no client can access data after revocation even if the route remains deployed.
