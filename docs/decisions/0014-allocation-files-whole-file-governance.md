# ADR-0014 · Genesis allocations are governed as whole, committee-approved files

- **Status:** accepted
- **Date:** 2026-06-20
- **Deciders:** project owner

## Context and problem statement

A launch's genesis needs curated allocations — initial accounts, vesting claims/grants, authz, feegrant.
An early design governed these **per entry** (`ADD/REMOVE/MODIFY_GENESIS_ACCOUNT` proposals). Per-entry
review doesn't scale to a human committee (thousands of airdrop rows → rubber-stamping). How should
allocations be governed?

## Decision

**Allocations are governed as whole files, one per fixed type, committee-approved and hash-anchored:**

- **Fixed 5-type enum** (`launch.AllocationType`): `accounts`, `claims`, `grants`, `authz`, `feegrant`
  (≤ 1 file per type).
- **Opaque bytes.** A committee member uploads the curated file for a type (`POST
  /launch/{id}/allocations/{type}`, dual-mode identical to the genesis upload: an attestor `{url, sha256}`
  ref **or** host bytes). **coordd stores + SHA-256-hashes the bytes but never parses them** — gentool
  emits CSV/TSV, and correctness is mechanical (gentool build + rehearsal), so the committee approves
  *provenance*, not content.
- **Hash-anchored approval.** Each file lands `PENDING`; a re-upload with a new hash resets it to
  `PENDING` (invalidating any prior approval). Approval is one `APPROVE_ALLOCATION_FILE` M-of-N proposal
  per file carrying `{type, hash}`, and the payload hash must equal the file's *current* hash at execute
  (a stale hash fails). A single VETO marks the file `REJECTED`.

## Consequences

- **Good:** review is per-file (a unit a committee can actually vet), with the hash as the integrity
  anchor; content stays opaque so coordd needs no allocation parser.
- **Good:** the approved files + hashes are the exact inputs gentool's `genesis.Build` and the rehearsal
  bridge consume — one contract across repos.
- **Trade-off:** coordd can't do content-level allocation checks (balances, denoms, vesting) — those are
  gentool's / rehearsal's job by design.

## Alternatives considered

- **Per-entry proposals** — removed: doesn't scale to human review → rubber-stamping.
- **coordd parses + validates allocations** — rejected: duplicates gentool's accounting and couples coordd
  to the CSV format.

## Related

- Reference: chaincoord [concepts/proposals.md](https://ny4rl4th0t3p.github.io/seedward-chaincoord/concepts/proposals/) (Allocation files). Folds into the input fingerprint:
  [ADR-0015](0015-input-set-hash.md). Consumed by gentool ([ADR-0004](0004-gentool-library-first-genesis-engine.md))
  + the bridge ([ADR-0007](0007-bridge-fact-based-trust-boundary.md)).
