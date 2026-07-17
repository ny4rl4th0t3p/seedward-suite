# ADR-0019 · Validators attest readiness by signing against the final genesis hash

- **Status:** accepted
- **Date:** 2026-04-15
- **Deciders:** project owner

## Context and problem statement

Before a launch goes, the committee needs to know validators are actually set up with the correct final
genesis + binary — a go/no-go signal. How is that confirmed, and how much voting power is ready?

## Decision

In `GENESIS_READY`, an approved validator submits a **signed readiness confirmation** (`POST
/launch/{id}/ready`):

- The operator signs (secp256k1, with a nonce + timestamp for replay protection) an attestation that
  `genesis_hash_confirmed == FinalGenesisSHA256` **and** `binary_hash_confirmed == Record.BinarySHA256`
  (the binary check is enforced only when the record declares a hash; otherwise stored, unchecked).
- Gated on an `APPROVED` join request + `GENESIS_READY`. **One valid confirmation per operator** per
  genesis version.
- A confirmation is **invalidated** when what it attested to changes — `UPDATE_GENESIS_TIME`,
  `REVISE_GENESIS`, or a cancel from `GENESIS_READY` — so validators re-confirm against the new state.
- The **dashboard** aggregates per-validator voting power into a threshold status — `CONFIRMED` (≥ ⅔ of
  voting power ready), `AT_RISK` (< 50 %), else `REACHABLE` — the committee's launch-go signal.

## Consequences

- **Good:** the go/no-go decision is backed by signed attestations tied to the exact genesis + binary, not
  self-reported clicks.
- **Good:** a change to the launch parameters visibly resets readiness, so nobody launches on a stale
  confirmation.
- The dashboard is a coordination contract the web renders.

## Alternatives considered

- **Unsigned "I'm ready" clicks** — rejected: not attributable or tied to the actual genesis/binary.
- **No re-confirmation on change** — rejected: would let a launch proceed on confirmations against a
  superseded genesis.

## Related

- The genesis hash it confirms: [ADR-0004](0004-gentool-library-first-genesis-engine.md) +
  [ADR-0018](0018-artifact-storage-attestor-or-host.md). The lifecycle state:
  [ADR-0009](0009-launch-lifecycle-state-machine.md). Reference: chaincoord [concepts/readiness.md](https://ny4rl4th0t3p.github.io/seedward-chaincoord/concepts/readiness/).
  (Note: `UPDATE_GENESIS_TIME` invalidates readiness but does not rebuild the genesis file — its exact
  semantics are a flagged open question.)
