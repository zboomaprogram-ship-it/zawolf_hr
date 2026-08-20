# Checkout Policy Feature

The checkout-policy feature is the client-facing clean-architecture boundary
for the server-authoritative, default-off check-out policy defined in
`specs/003-checkout-retirement/`.

The client must treat missing, malformed, or unavailable policy data as
disabled. Only the backend can authorize a change.
