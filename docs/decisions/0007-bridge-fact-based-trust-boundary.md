# ADR-0007 · The coordd↔rehearsal bridge is an ops-plane, fact-based trust boundary

- **Status:** accepted
- **Date:** 2026-07-03
- **Deciders:** project owner

## Context and problem statement

The rehearsal service and coordd must exchange rehearsal inputs and results. Who initiates, how do they
authenticate, and where does trust live — in the caller's identity, or in the data exchanged?

## Decision

The bridge is an **ops-plane, fact-based** boundary:

- **coordd never initiates.** Both directions are initiated by the rehearsal service (it pulls inputs,
  pushes the result fact); coordd only serves, authorizes, and accepts.
- **Ops plane, not committee identity.** Bridge calls authenticate with an infrastructure credential —
  one deployment-wide, file-based bearer token (`rehearsal_ops_token`), constant-time compared — under a
  dedicated **`/bridge/*` prefix** so the whole surface can be network-restricted to an internal VNet
  with one rule. The rehearsal service is a headless daemon with no wallet.
- **Trust is in the fact, not the trigger.** The result fact is Ed25519-signed by the service's own key;
  coordd verifies it against a **per-launch trusted service pubkey** recorded on the launch record (not
  the self-declared key in the fact). The coarse shared token gates *access*; the per-launch pubkey gates
  the trust-critical *write*.
- **coordd serves input as-is; judgment lives in the service.** No runnability/status gate on the read —
  an insufficient set yields the rehearsal's own `FAIL`. Which statuses are worth running is the
  service's operator config (→ a `SKIPPED` outcome, never a misleading `FAIL`).

## Consequences

- **Good:** the network boundary is one rule; coordd holds no wallet-identity trust for rehearsal; a
  leaked ops token still cannot forge a *result* (that needs the per-launch key).
- **Good:** coordd stays a coordinator — it never executes rehearsals, only stores facts and applies
  rules over them (the gate, the cap).
- **Trade-off:** the ops token is coarse (deployment-wide); per-launch tokens / mTLS are deferred to
  v1.x — acceptable because the write is gated by the per-launch pubkey.

## Alternatives considered

- **coordd initiates rehearsals** — rejected: inverts the dependency ([ADR-0003](0003-rehearsal-optional-bolt-on.md))
  and makes coordd's availability depend on the service.
- **Committee-identity auth on the bridge** — rejected: the service is headless with no wallet; a
  committee session doesn't fit an ops plane.
- **Trust the trigger/caller** — rejected: trust must survive the transport, so it lives in the signed fact.

## Related

- Wire contract: [Bridge contract](../reference/bridge-contract.md). Result integrity + lease:
  [ADR-0008](0008-rehearsal-write-back-and-lease.md).
