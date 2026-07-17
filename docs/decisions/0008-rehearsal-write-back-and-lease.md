# ADR-0008 · Rehearsal result write-back: coordd-minted attempts + claim-before-run lease

- **Status:** accepted
- **Date:** 2026-07-04
- **Deciders:** project owner

## Context and problem statement

A rehearsal result is written back to coordd by an external service. How does coordd know a result
corresponds to inputs it actually served (not a fabricated hash), and how are concurrent or looping
runners kept from stampeding a launch?

## Decision

Two mechanisms:

- **Coordd-minted attempts (anti-fabrication).** A run must reference an `attempt_id` coordd minted for
  *this* launch, whose `input_set_hash` matches; a fact echoing a hash coordd never served is **rejected
  400 as fabricated**. A genuine result whose input set has since drifted is **stored and flagged
  `stale`** (never discarded). Write-back is **idempotent** on the fact signature. The binding vouches the
  *input set was genuine*, not that the *verdict is honest* — verdict trust stays with the Ed25519
  signature ([ADR-0007](0007-bridge-fact-based-trust-boundary.md)).
- **Claim-before-run lease (single-flight).** The run entry point is `POST rehearsal-claim {runner_id}`,
  which mints the attempt AND acquires a single-writer lease on `(launch, input_set_hash)`. A second
  runner gets **409**; the same runner re-claiming is a no-op that does **not** extend the deadline (a
  crash-looping runner can't hold the lease past its window). The lease **auto-expires** after a TTL
  (default 45 min, evaluated lazily), and a committee member can force-release it via a governance-plane
  reset. Consequently `GET rehearsal-input` is a **read-only preview** (no mint, no lease) — a runner MUST
  claim to get a usable `attempt_id`, which makes "claimed before recorded" enforceable.

## Consequences

- **Good:** coordd never stores a result for inputs it didn't serve; stale-but-genuine results stay
  visible, not lost; concurrent runners can't double-run a set; a stuck runner self-heals via TTL.
- Committee read-back of stored results is on the **governance plane** (`GET /launch/{id}/rehearsal`), not
  the bridge.
- **Deferred (v1.x):** an attempt **cap** per `(launch, input_set_hash)` to hard-stop a looping runner —
  low-urgency while triggers are manual and single-service.

## Alternatives considered

- **Accept any signed fact (no attempt binding)** — rejected: lets a service record results for input
  sets coordd never served.
- **Discard stale results** — rejected: a genuine drifted result is informative; flag it, don't lose it.
- **No lease in v1** (the earlier stance) — reversed: single-flight + self-heal are cheap and prevent
  double-runs even in the manual flow.

## Related

- Wire contract: [Bridge contract](../reference/bridge-contract.md) (§4, §5.1). Trust model:
  [ADR-0007](0007-bridge-fact-based-trust-boundary.md).
