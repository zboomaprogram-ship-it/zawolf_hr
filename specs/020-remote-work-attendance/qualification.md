# Remote Work Qualification and Emulator Instructions

**Status:** Owner selected HR-approved registration plus passkey for personal computers. Emulator evidence exists; no real target browser/credential journey has been qualified.

## Firestore emulator baseline

Run from the repository root. The project ID is deliberately a `demo-*` ID, and the fixture refuses emulator hosts outside loopback or non-demo/test project IDs.

```bash
firebase emulators:exec --only firestore --project demo-remote-work \
  'cd scripts && RUN_REMOTE_WORK_EMULATOR=1 FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 GCLOUD_PROJECT=demo-remote-work node --test test/remote-work-emulator.test.js'
```

`emulators:exec` starts Firestore, runs the test command, and stops the emulator when the command exits. For an interactive session, use two terminals:

```bash
firebase emulators:start --only firestore --project demo-remote-work
```

```bash
cd scripts
RUN_REMOTE_WORK_EMULATOR=1 FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 GCLOUD_PROJECT=demo-remote-work node --test test/remote-work-emulator.test.js
```

Stop an interactive emulator with Ctrl+C. The test writes only to the emulator and deletes its Firebase Admin app in `finally`; it does not deploy rules or indexes.

## Hardware and browser profile

T01 remains open. Record the supported OS/browser inventory, origin and RP ID, credential policy, recovery owner, and observed registration/assertion results here only after testing the real target fleet. WebAuthn support by itself does not establish that a credential is tied to one approved computer. Until evidence is recorded and reviewed, no computer assurance profile is available for publication or rollout.

## Target fleet and origin — owner confirmation 2026-10-27

Employees use Windows personal computers with Chrome or Brave. The app origin is `https://zawolf-hr-system-60317.web.app`; the proposed RP ID is `zawolf-hr-system-60317.web.app` (host only). The API lives separately; WebAuthn assertions are verified against the app origin and RP ID, not the API host. Browser/Windows versions, Windows Hello/authenticator availability, actual registration/assertion and cross-device behavior, revocation, replay, recovery ownership, and deployed Node version remain unverified. The owner-provided fleet/origin is a target specification, not successful device qualification.

## Owner decision — 2026-10-26

Remote days use employees' personal computers; office days use company computers. The owner explicitly selected **HR-approved registration plus passkey**, accepting that a synced passkey may be usable from another computer. Use profile ID `hr_approved_passkey`; do not describe this profile as binding to one physical computer. The enrolled-credential limit is not a physical-computer limit. Phone attendance binding remains independent.

Registration requires HR approval and server-verified registration; each attendance action requires fresh challenge/origin/RP/signature/user-verification validation and the approved credential. Record backup eligibility/state as credential metadata rather than rejecting synced credentials under this profile. An unapproved credential, wrong employee/company, revoked enrollment or replay still rejects. Unsupported/mobile remote clients remain unsupported unless separately qualified and permitted.

The [WebAuthn specification](https://www.w3.org/TR/2026/REC-webauthn-3-20260825/#sctn-credential-backup) defines multi-device credentials and mutable backup state. [SimpleWebAuthn's server documentation](https://simplewebauthn.dev/docs/packages/server) documents version 14.0.x and Node LTS 22+, origin/RP validation, user verification and credential backup metadata. Version 14.0.3 is pinned in the backend package; backend `engines.node` requires >=22. The deployed Hostinger runtime has not been verified and remains a rollout gate.

## Production verifier virtual-browser journey — 2026-10-27

The production verifier/options adapter passed locally with Chrome 150.0.7871.125, Node 22.19.0 and `@simplewebauthn/server@14.0.3`, using a virtual CTAP2 authenticator on localhost. Registration and assertion passed; the credential reported `multiDevice` and backed-up. Challenge consumption succeeded once in the same local action transaction; replay and missing user verification were rejected. The same adapter also passed on Windows Server 2022 with Chrome and Brave in [CI](https://github.com/zboomaprogram-ship-it/zawolf_hr/actions/runs/40469958222). These tests validate verifier calls in virtual browsers, not real hardware, Windows Hello or the production domain.

Still required: actual OS/browser versions and authenticator inventory, observed registration/assertion and replay/revocation tests on Windows Chrome and Brave at the confirmed origin, the compatible pinned library/deployed Node runtime, recovery owner and retention approval. The earlier physical-computer-binding gate is superseded for the selected profile; these remaining credential/browser checks are not waived. No profile is marked qualified or enabled for production by this document.

## Alternative Windows virtual-browser tests — 2026-10-27

The owner cannot test on a Windows computer. An isolated test-only GitHub branch ran the locked spike on Windows Server 2022 with Chrome and Brave; both jobs passed: [Windows CI run](https://github.com/zboomaprogram-ship-it/zawolf_hr/actions/runs/40466096604). The spike uses a virtual CTAP2 authenticator on localhost and checks registration and assertion, origin, RP ID, challenge, signature and required user verification; it records a multi-device backed-up credential. The test also confirms the library accepts replay unless the application atomically consumes its challenge. No production data or authentication was used.

This is useful automated Windows browser evidence, but it does not test Windows Hello, real hardware, the production origin, credential revocation or the unfinished application integration. Those remain qualification requirements.
